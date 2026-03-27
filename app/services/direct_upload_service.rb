# frozen_string_literal: true

require "base64"

class DirectUploadService
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class InvalidTokenError < Error; end
  class UploadNotFoundError < Error; end
  class QuotaExceededError < Error; end

  DIRECT_UPLOAD_URL_TTL = 15.minutes
  FINALIZE_TOKEN_TTL = 30.minutes

  def initialize(user)
    @user = user
  end

  def prepare(filename:, byte_size:, content_type:, provenance:)
    ensure_storage_configuration!

    quota_service = QuotaService.new(@user)
    policy = quota_service.current_policy

    if byte_size > policy.max_file_size
      raise QuotaExceededError,
        "File size (#{ActiveSupport::NumberHelper.number_to_human_size(byte_size)}) exceeds your limit of #{ActiveSupport::NumberHelper.number_to_human_size(policy.max_file_size)} per file."
    end

    unless quota_service.can_upload?(byte_size)
      usage = quota_service.current_usage
      raise QuotaExceededError,
        "Uploading this file would exceed your storage quota. You're using #{ActiveSupport::NumberHelper.number_to_human_size(usage[:storage_used])} of #{ActiveSupport::NumberHelper.number_to_human_size(usage[:storage_limit])}."
    end

    upload_id = SecureRandom.uuid_v7
    normalized_content_type = Upload.normalize_content_type(content_type.presence || "application/octet-stream")
    sanitized_filename = ActiveStorage::Filename.new(filename).sanitized
    key = "#{upload_id}/#{sanitized_filename}"

    {
      upload_id: upload_id,
      upload_url: presigner.presigned_url(
        :put_object,
        bucket: bucket_name,
        key: key,
        expires_in: DIRECT_UPLOAD_URL_TTL.to_i,
        content_type: normalized_content_type
      ),
      headers: {
        "Content-Type" => normalized_content_type
      },
      finalize_token: verifier.generate(
        {
          user_id: @user.id,
          upload_id: upload_id,
          key: key,
          filename: filename,
          content_type: normalized_content_type,
          provenance: provenance.to_s
        },
        expires_in: FINALIZE_TOKEN_TTL
      )
    }
  end

  def finalize(finalize_token:)
    payload = verifier.verify(finalize_token).deep_symbolize_keys
    raise InvalidTokenError, "Upload token does not belong to the current user." unless payload[:user_id] == @user.id

    existing_upload = @user.uploads.includes(:blob).find_by(id: payload[:upload_id])
    return existing_upload if existing_upload.present?

    object = client.head_object(bucket: bucket_name, key: payload[:key])
    byte_size = object.content_length
    content_type = Upload.normalize_content_type(object.content_type.presence || payload[:content_type] || "application/octet-stream")

    quota_service = QuotaService.new(@user)
    policy = quota_service.current_policy

    if byte_size > policy.max_file_size
      cleanup_object(payload[:key])
      raise QuotaExceededError,
        "File size (#{ActiveSupport::NumberHelper.number_to_human_size(byte_size)}) exceeds your limit of #{ActiveSupport::NumberHelper.number_to_human_size(policy.max_file_size)} per file."
    end

    unless quota_service.can_upload?(byte_size)
      cleanup_object(payload[:key])
      usage = quota_service.current_usage
      raise QuotaExceededError,
        "Uploading this file would exceed your storage quota. You're using #{ActiveSupport::NumberHelper.number_to_human_size(usage[:storage_used])} of #{ActiveSupport::NumberHelper.number_to_human_size(usage[:storage_limit])}."
    end

    blob = ActiveStorage::Blob.create!(
      key: payload[:key],
      filename: payload[:filename],
      content_type: content_type,
      byte_size: byte_size,
      checksum: checksum_from_etag(object.etag),
      service_name: ActiveStorage::Blob.service.name
    )

    @user.uploads.create!(
      id: payload[:upload_id],
      blob: blob,
      provenance: payload[:provenance]
    )
  rescue Aws::S3::Errors::NotFound, Aws::S3::Errors::NoSuchKey
    raise UploadNotFoundError, "Uploaded file could not be found in storage."
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    raise InvalidTokenError, "Upload token is invalid or expired."
  end

  private

  def checksum_from_etag(etag)
    hex = etag.to_s.delete('"')
    Base64.strict_encode64([ hex ].pack("H*"))
  end

  def cleanup_object(key)
    client.delete_object(bucket: bucket_name, key: key)
  rescue Aws::S3::Errors::ServiceError => e
    Rails.logger.warn("Failed to delete direct-uploaded object #{key}: #{e.message}")
  end

  def ensure_storage_configuration!
    missing = %w[R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY R2_BUCKET_NAME R2_ENDPOINT].select { |name| ENV[name].blank? }
    return if missing.empty?

    raise ConfigurationError, "Missing storage configuration: #{missing.join(', ')}"
  end

  def verifier
    Rails.application.message_verifier("direct-upload")
  end

  def presigner
    Aws::S3::Presigner.new(client: client)
  end

  def client
    @client ||= Aws::S3::Client.new(
      access_key_id: ENV["R2_ACCESS_KEY_ID"],
      secret_access_key: ENV["R2_SECRET_ACCESS_KEY"],
      region: "auto",
      endpoint: ENV["R2_ENDPOINT"],
      force_path_style: true,
      request_checksum_calculation: "when_required",
      response_checksum_validation: "when_required"
    )
  end

  def bucket_name
    ENV.fetch("R2_BUCKET_NAME")
  end
end
