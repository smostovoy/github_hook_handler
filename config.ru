require 'json'
require 'yaml'
require 'logger'

$config = YAML.load_file("config.yaml")

class GithubHook
  def call(env)
    req = Rack::Request.new(env)
    logger = Logger.new($config["log_file"] || STDOUT)
    commit_info = JSON.parse req['payload']
    repo = commit_info['repository']

    project_id = "#{repo['owner']['name']}/#{repo['name']}"
    project = $config["projects"][project_id]

    if project
        ref = commit_info["ref"].match(/\w+$/)[0]

        ref_deploy_path = File.join project['deploy_to'], ref

        if File.directory? ref_deploy_path
            logger.info "Updating existing directory"
            logger.info `cd #{ref_deploy_path}; git reset --hard; git pull`
        else
            logger.info `cd #{project['deploy_to']}; git clone #{project['repo']} #{ref}; cd #{ref_deploy_path}; git checkout -b #{ref} origin/#{ref}`
        end

        if project['run_after']
          project['run_after'].gsub(/\$path/, ref_deploy_path).split("\n").each do |command|
            logger.info `#{command}`
          end
        end

    else
        throw "Cant find configuration for '#{project_id}' project"
    end

    return [200, {'Content-Type' => 'text/html'}, ["Success!"]]
  end
end

run GithubHook.new

