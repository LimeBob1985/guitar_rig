require 'yaml'

def flutter_install_all_ios_pods(ios_application_path = nil)
  flutter_application_path ||= File.join(ios_application_path, '..')
  pubspec = YAML.load_file(File.join(flutter_application_path, 'pubspec.yaml'))
  return if pubspec.nil?
end

def flutter_additional_ios_build_settings(target)
  target.build_configurations.each do |config|
    config.build_settings['ENABLE_BITCODE'] = 'NO'
  end
end
