require 'fileutils'
require 'yaml'
require 'open-uri'
require 'json'
@conf = YAML.load_file("config/project_settings.yml")
@testdata = YAML.load_file("config/test_settings.yml")
@environment = ENV['environment'] ? ENV['environment'] : @testdata['environment']

# rake helper functions for android tasks
namespace :android do
  include FileUtils

  def apks
    @apks ||= Dir[@conf['project']['build_dir'] + "/*.apk"]
    if @apks.empty?
      puts "ERROR: No APK's found in #{@conf['project']['build_dir']} ..aborting"
      exit 1
    end
    @apks
  end

  def default_apk
    @default_apk ||= apks.find { |apk_name| apk_name.include? @environment }
  end

  def generate_directories
    build_dir = @conf['project']['build_dir']
    exec("rm -rf #{build_dir}") if File.directory?(build_dir)
    mkdir build_dir
  end

  def download_apk(params = {})
    operation_type = 'wget'
    if ENV['endpoint_type'] == 'local'
      operation_type = 'cp -rf'
    end
    if ENV['endpoint_download']
      path = ENV['endpoint_download']
    else
      path = @conf['remote']['endpoint_download']
    end
    if params[:buildnumber]
      puts "Using specified build number #{params[:buildnumber]}"
      path = @conf['remote']['endpoint_download_build']
      path = path.gsub('BUILDNUM', params[:buildnumber])
    end

    if !ENV['username'] && !ENV['password']
      puts "Please provide your username & password for teamcity e.g. rake android:setup username=AlexJones password=ThisisMyPassword"
      exit
    else
      puts "Connecting as '#{ENV['username']}'"
    end

    path = path.gsub("UNAME", ENV['username'])
    path = path.gsub("PWORD", ENV['password'])
    puts "Operation type #{operation_type} on path #{path}"

    `#{operation_type} #{path} -P #{@conf['project']['build_dir']}`
    if ENV['endpoint_payload']
      payload = ENV['endpoint_payload']
    else
      payload = @conf['remote']['endpoint_payload']
    end
    Dir.chdir(@conf['project']['build_dir']) do
      `unzip #{payload} 2>/dev/null`
      `mv apk/*.apk . 2>/dev/null`
    end
  end

  def resign_apk(apk_file)
    `rm -rf test_servers` if File.directory?('test_servers')
    `calabash-android resign #{apk_file}`
  end

  def display_installed_apk
    puts `adb shell pm list packages | grep blinkbox`
  end
end

#android rake tasks
namespace :android do
  desc "Get latest android APK"
  task :get_latest_apk do
    generate_directories
    download_apk
    puts default_apk
  end

  desc "builds and resigns the apk"
  task :resign, [:apk_file] do |_, args|
    apk_file = args[:apk_file] || default_apk
    puts "I'm resigning ..."+apk_file
    resign_apk(apk_file)
    puts "I resigned ..."+apk_file
  end

  desc "Installs the apk and test server (will reinstall if installed)"
  task :install_apk, [:apk_file] do |_, args|
    apk_file = args[:apk_file] || default_apk
    puts "I'm installing ..."+apk_file
    `adb install -r #{apk_file}`
    puts "I installed ..."+apk_file
  end

  desc "Gets the latest apk, resigns it and installs the apk, optional argument for a specified build"
  task :setup, [:buildnumber] do |_, args|
    buildn = args[:buildnumber]
    if buildn
      puts buildn
      generate_directories
      download_apk(:buildnumber => buildn)
      puts default_apk
    else
      Rake::Task["android:get_latest_apk"].invoke
    end
    Rake::Task["android:resign"].invoke
    Rake::Task["android:install_apk"].invoke
  end

  desc "Displays installed blinkbox APK's on device (Requires connected device)"
  task :display_installed_apk do
    display_installed_apk
  end

  desc "Removes installed blinkbox packages on device (Requires connected device)"
  task :uninstall_apk do
    base_package = "com.blinkboxbooks.android"
    packages = [base_package, base_package+".qa", base_package+".qa.test", base_package+".test", base_package+".dev"]
    packages.each do |package|
      puts "I am now uninstalling...#{package}"
      `adb shell pm uninstall #{package}`
    end
  end

end

#calabash rake tasks
namespace :calabash do
  desc "Prints out details about current configuration"
  task :run_config do
    puts "Tests are currently to run on #{@testdata['test']['device']} under #{@testdata['test']['environment']} configuration"
  end

  desc "Checks development environment and install essentials"
  task :environment_install do
    exec("./config/dev_env_install")
  end

  desc 'Run calabash-android console with included Calabash::Android::Operations, as well as android-test support modules & page models'
  task :console, [:apk_file] do |_, args|
    apk_file = args[:apk_file] || default_apk
    ENV['CALABASH_IRBRC'] = File.join(File.dirname(__FILE__), 'irbrc')
    puts "REMEMBER: to run 'rake android:resign[#{apk_file}]', if you have issues running this APK"
    exec "calabash-android console #{apk_file}"
  end

  desc "Runs calabash android"
  task :run, [:apk_file] do |_, args|
    apk_file = args[:apk_file] || default_apk
    puts "Running with environment:#{@environment}"
    puts "REMEMBER: to run 'rake android:resign[#{apk_file}]', if you have issues running this APK"
    formatter = ENV['formatter'] ? ENV['formatter'] : "LoggedFormatter"
    output_path = ENV['output'] ? ENV['output'] : ""
    puts "Using formatter #{formatter}"

    if ENV["feature"]
      puts "RUNNING: feature=#{ENV["feature"]}"
      output = `calabash-android run #{apk_file} #{ENV["feature"]} -f #{formatter} -o #{output_path} -f pretty`
    elsif ENV["profile"]
      output = `calabash-android run #{apk_file} --profile=#{ENV['profile']} -f #{formatter} -o #{output_path}`
    else
      output = `calabash-android run #{apk_file}`
    end
    puts output
  end

  desc "Runs calabash android with given profile"
  task :run_with_profile, [:profile, :apk_file] do |_t, args|
    profile = args[:profile] || 'default'
    apk_file = args[:apk_file] || default_apk
    puts "REMEMBER: to run 'rake android:resign[#{apk_file}]', if you have issues running this APK"
    puts "The env is...#{ENV['environment']}"
    puts "You are running with the apk...#{apk_file}"
    puts "You are running with the profile...#{profile}"
    exec("calabash-android run #{apk_file} -p #{profile}")
  end
end

namespace :scaffold do
  desc "Generates a new page object class. Page name should be provided as the first argument: rake scaffold:page['my new page']"
  task :page, [:name] do |_t, args|
    name = args[:name]
    fail "Page name should be provided as the first argument: rake scaffold:page['my new page']" if (name.nil? || name.empty?)

    down_cased = name.downcase.tr(' -', '_')
    filename = "features/pages/#{down_cased}.rb"
    classname = name.tr('-_', ' ').split().map { |word| word.capitalize }.join

    fail "File #{filename} already exists" if File.exist?(filename)

    content = %Q{module PageObjectModel
  class #{classname} < PageObjectModel::Page
    #TODO: define a unique page trait, which will be use to check if page is displayed or not. Example:
    #trait "BBBTextView marked:'Your library'"
    #TODO: define elements by using #element keyword:
    #element :shop_button, "* id:'button_shop'"
  end
end

module PageObjectModel
  def #{down_cased}
    @_#{down_cased} ||= page(#{classname})
  end
end
}
    File.open(filename, 'w') { |file| file.write(content) }
    puts "Generated page model scaffold: #{filename}"
  end
end

task :default do
  #endpoint_download=custom endpoint
  #endpoint_payload=customise what is being downloaded e.g. 'apk.zip', 'apk.tar.gz'
  #configuration=custom configuration
end
