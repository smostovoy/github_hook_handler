require 'json'
require 'yaml'

$config = YAML.load_file("config.yaml")

class GithubHook
  def call(env)
    req = Rack::Request.new(env)    

    commit_info = JSON.parse req['payload']
    repo = commit_info['repository']
    
    project_id = "#{repo['owner']['name']}/#{repo['name']}" 
    project = $config["projects"][project_id]

    if project
        ref = commit_info["ref"].match(/\w+$/)[0]

        ref_deploy_path = File.join project['deploy_to'], ref

        if File.directory? ref_deploy_path
            print "Updating existing directory"
            `cd #{ref_deploy_path}; git pull`
        else
            `cd #{project['deploy_to']}; git clone #{project['repo']} #{ref}; cd #{ref_deploy_path}; git checkout -b #{ref} origin/#{ref}`
        end

        `#{project['run_after'].replace(/\$path/, ref_deploy_path)}` if project['run_after']
    else
        throw "Cant find configuration for '#{project_id}' project"
    end

    return [200, {'Content-Type' => 'text/html'}, ["Success!"]]
  end
end

run GithubHook.new

