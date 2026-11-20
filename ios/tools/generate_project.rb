# Regenerates Math7.xcodeproj from the files in this folder.
# Usage (from the ios/ folder):  gem install xcodeproj && ruby tools/generate_project.rb
require 'xcodeproj'

ROOT = File.expand_path('..', __dir__)
Dir.chdir(ROOT)
PROJECT_PATH = 'Math7.xcodeproj'
FileUtils.rm_rf(PROJECT_PATH)
project = Xcodeproj::Project.new(PROJECT_PATH)
DEPLOY = '17.0'

# ---------- groups and file references ----------
main = project.main_group
config_ref = main.new_group('Config', 'Config').new_file('Settings.xcconfig')
project.build_configurations.each { |c| c.base_configuration_reference = config_ref }

def add_tree(group, dir)
  refs = []
  Dir.children(dir).sort.each do |name|
    path = File.join(dir, name)
    next if name.start_with?('.')
    if File.directory?(path) && !name.end_with?('.xcassets')
      refs += add_tree(group.new_group(name, name), path)
    else
      refs << group.new_file(name)
    end
  end
  refs
end

app_group = main.new_group('Math7', 'Math7')
app_refs = add_tree(app_group, 'Math7')
shared_refs = add_tree(main.new_group('Shared', 'Shared'), 'Shared')
monitor_refs = add_tree(main.new_group('Math7Monitor', 'Math7Monitor'), 'Math7Monitor')
shield_refs = add_tree(main.new_group('Math7Shield', 'Math7Shield'), 'Math7Shield')
# The problem bank is shared with the web app one folder up.
problems_ref = main.new_group('Shared with web app', '..').new_file('problems.js')

swift = ->(refs) { refs.select { |r| r.path.end_with?('.swift') } }
resources = app_refs.select { |r| r.path.end_with?('.html', '.xcassets') } + [problems_ref]

COMMON = {
  'SWIFT_VERSION' => '5.0',
  'IPHONEOS_DEPLOYMENT_TARGET' => DEPLOY,
  'TARGETED_DEVICE_FAMILY' => '2',
  'CODE_SIGN_STYLE' => 'Automatic',
  'GENERATE_INFOPLIST_FILE' => 'YES',
  'CURRENT_PROJECT_VERSION' => '1',
  'MARKETING_VERSION' => '1.0',
  'SWIFT_EMIT_LOC_STRINGS' => 'NO',
  'ENABLE_USER_SCRIPT_SANDBOXING' => 'YES',
}

def configure(target, settings)
  target.build_configurations.each do |c|
    c.build_settings.merge!(COMMON).merge!(settings)
    conds = settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS']
    if conds && c.name == 'Debug'
      c.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = conds + ' DEBUG'
    end
  end
end

def app_settings(product, gate, entitlements)
  s = {
    'PRODUCT_NAME' => product,
    'PRODUCT_BUNDLE_IDENTIFIER' => '$(BUNDLE_ID_PREFIX)',
    'INFOPLIST_KEY_CFBundleDisplayName' => 'Math 7',
    'INFOPLIST_KEY_UILaunchScreen_Generation' => 'YES',
    'INFOPLIST_KEY_UIApplicationSceneManifest_Generation' => 'YES',
    'INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad' =>
      'UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight',
    'INFOPLIST_KEY_LSApplicationCategoryType' => 'public.app-category.education',
    'ASSETCATALOG_COMPILER_APPICON_NAME' => 'AppIcon',
    'ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME' => 'AccentColor',
    'LD_RUNPATH_SEARCH_PATHS' => '$(inherited) @executable_path/Frameworks',
    'ENABLE_PREVIEWS' => 'YES',
    'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => "$(inherited) #{gate}",
  }
  s['CODE_SIGN_ENTITLEMENTS'] = entitlements if entitlements
  s
end

def ext_settings(name, suffix)
  {
    'PRODUCT_NAME' => name,
    'PRODUCT_BUNDLE_IDENTIFIER' => "$(BUNDLE_ID_PREFIX).#{suffix}",
    'INFOPLIST_FILE' => "#{name}/Info.plist",
    'INFOPLIST_KEY_CFBundleDisplayName' => name,
    'CODE_SIGN_ENTITLEMENTS' => "#{name}/#{name}.entitlements",
    'SKIP_INSTALL' => 'YES',
    'APPLICATION_EXTENSION_API_ONLY' => 'YES',
    'LD_RUNPATH_SEARCH_PATHS' => '$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks',
  }
end

def strip_frameworks(target)
  # new_target links Foundation by default; Swift autolinks what it needs.
  target.frameworks_build_phase.files.to_a.each { |f| target.frameworks_build_phase.remove_build_file(f) }
end

# ---------- targets ----------
free = project.new_target(:application, 'Math7', :ios, DEPLOY)
free.add_file_references(swift.(app_refs) + swift.(shared_refs))
free.add_resources(resources)
configure(free, app_settings('Math7', 'GATE_Off', nil))
strip_frameworks(free)

locked = project.new_target(:application, 'Math7Lock', :ios, DEPLOY)
locked.add_file_references(swift.(app_refs) + swift.(shared_refs))
locked.add_resources(resources)
configure(locked, app_settings('Math7Lock', 'GATE_On', 'Math7/Math7Lock.entitlements'))
strip_frameworks(locked)

monitor = project.new_target(:app_extension, 'Math7Monitor', :ios, DEPLOY)
monitor.add_file_references(swift.(monitor_refs) + swift.(shared_refs))
configure(monitor, ext_settings('Math7Monitor', 'monitor'))
strip_frameworks(monitor)

shield = project.new_target(:app_extension, 'Math7Shield', :ios, DEPLOY)
shield.add_file_references(swift.(shield_refs))
configure(shield, ext_settings('Math7Shield', 'shield'))
strip_frameworks(shield)

embed = locked.new_copy_files_build_phase('Embed Foundation Extensions')
embed.symbol_dst_subfolder_spec = :plug_ins
[monitor, shield].each do |ext|
  locked.add_dependency(ext)
  bf = embed.add_file_reference(ext.product_reference, true)
  bf.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
end

# Remove the files that new_target puts in the root group's Products only (keep), and sort.
project.root_object.attributes['LastUpgradeCheck'] = '2600'
project.root_object.attributes['TargetAttributes'] = {}
project.sort

project.save

# ---------- schemes ----------
def scheme(project, target, name)
  s = Xcodeproj::XCScheme.new
  s.configure_with_targets(target, nil, launch_target: true)
  s.save_as(project.path, name, true)
end
scheme(project, free, 'Math7')
scheme(project, locked, 'Math7 with Roblox Lock')
puts "Wrote #{PROJECT_PATH}"
