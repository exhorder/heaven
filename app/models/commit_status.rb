class CommitStatus
  attr_accessor :guid, :payload, :token

  def initialize(guid, payload, token)
    @guid    = guid
    @token   = token
    @payload = payload
  end

  def data
    @data ||= JSON.parse(payload)
  end

  def api
    @api ||= Octokit::Client.new(:access_token => token)
  end

  def successful?
    state == "success"
  end

  def sha
    data["sha"][0..7]
  end

  def state
    data["state"]
  end

  def branches
    @branches ||= data["branches"]
  end

  def default_branch
    data["repository"]["default_branch"]
  end

  def default_branch?
    branches.any? { |branch| branch["name"] == default_branch }
  end

  def name_with_owner
    data["repository"]["full_name"]
  end

  def author
    data["commit"]["commit"]["author"]["login"]
  end

  def run!
    if successful?
      if default_branch?
        Deployment.latest_for_name_with_owner(name_with_owner).each do |deployment|
          Rails.logger.info "Finna tryna deploy #{name_with_owner}@#{sha} to #{deployment.environment}"
          AutoDeployment.new(deployment, self, token).execute
        end
      else
        branch = branches && branches.any? && branches.first['name']
        Rails.logger.info "Ignoring commit status(#{state}) for #{name_with_owner}+#{branch}@#{sha}"
      end
    end
  end
end
