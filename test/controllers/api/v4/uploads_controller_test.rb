# frozen_string_literal: true

require "test_helper"

class API::V4::UploadsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @api_key = @user.api_keys.create!(name: "Test Key")
    @token = @api_key.token
  end

  test "should upload file with valid token" do
    file = fixture_file_upload("test.png", "image/png")

    assert_difference("Upload.count", 1) do
      post api_v4_upload_url,
        params: { file: file },
        headers: { "Authorization" => "Bearer #{@token}" }
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert json["id"].present?
    assert_equal "test.png", json["filename"]
    assert json["url"].present?
    assert json["created_at"].present?
  end

  test "should reject upload without token" do
    file = fixture_file_upload("test.png", "image/png")

    post api_v4_upload_url, params: { file: file }

    assert_response :unauthorized
  end

  test "should reject upload without file parameter" do
    post api_v4_upload_url,
      headers: { "Authorization" => "Bearer #{@token}" }

    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_equal "Missing file parameter", json["error"]
  end

  test "should upload from URL with valid token" do
    upload = @user.uploads.create!(
      id: SecureRandom.uuid_v7,
      blob: ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new("fake image data"),
        filename: "test.jpg",
        content_type: "image/jpeg"
      ),
      provenance: :api
    )

    Upload.stub :create_from_url, upload do
      assert_no_difference("Upload.count") do
        post api_v4_upload_from_url_url,
          params: { url: "https://example.com/test.jpg" }.to_json,
          headers: {
            "Authorization" => "Bearer #{@token}",
            "Content-Type" => "application/json"
          }
      end
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert json["id"].present?
    assert json["url"].present?
  end

  test "should reject upload from URL without url parameter" do
    post api_v4_upload_from_url_url,
      params: {}.to_json,
      headers: {
        "Authorization" => "Bearer #{@token}",
        "Content-Type" => "application/json"
      }

    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_equal "Missing url parameter", json["error"]
  end

  test "should handle upload errors gracefully" do
    Upload.stub :create_from_url, ->(*) { raise StandardError, "Network error" } do
      post api_v4_upload_from_url_url,
        params: { url: "https://example.com/broken.jpg" }.to_json,
        headers: {
          "Authorization" => "Bearer #{@token}",
          "Content-Type" => "application/json"
        }
    end

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert json["error"].include?("Upload failed")
  end

  test "should prepare direct upload with valid token" do
    prepared_upload = {
      upload_id: SecureRandom.uuid_v7,
      upload_url: "https://uploads.example.com/object",
      headers: { "Content-Type" => "video/mp4" },
      finalize_token: "signed-token"
    }
    service = Struct.new(:response) do
      def prepare(**)
        response
      end
    end.new(prepared_upload)

    DirectUploadService.stub :new, service do
      post "/api/v4/direct_upload",
        params: { filename: "video.mp4", byte_size: 1234, content_type: "video/mp4" }.to_json,
        headers: {
          "Authorization" => "Bearer #{@token}",
          "Content-Type" => "application/json"
        }
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "signed-token", json["finalize_token"]
  end

  test "should finalize direct upload with valid token" do
    upload = @user.uploads.create!(
      id: SecureRandom.uuid_v7,
      blob: ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new("fake image data"),
        filename: "test.jpg",
        content_type: "image/jpeg"
      ),
      provenance: :api
    )
    service = Struct.new(:upload) do
      def finalize(**)
        upload
      end
    end.new(upload)

    DirectUploadService.stub :new, service do
      post "/api/v4/complete_upload",
        params: { finalize_token: "signed-token" }.to_json,
        headers: {
          "Authorization" => "Bearer #{@token}",
          "Content-Type" => "application/json"
        }
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal upload.id, json["id"]
  end
end
