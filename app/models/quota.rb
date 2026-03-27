class Quota
  Policy = Data.define(:slug, :max_file_size, :max_total_storage)

  ALL_POLICIES = [
    Policy[:unverified, 2.gigabytes, 50.gigabytes],
    Policy[:verified, 2.gigabytes, 300.gigabytes],
    Policy[:functionally_unlimited, 2.gigabytes, 2.terabytes]
  ].index_by &:slug

  ADMIN_ASSIGNABLE = %i[verified functionally_unlimited].freeze

  def self.policy(slug) = ALL_POLICIES.fetch slug
end
