require 'xcodeproj'
require 'rexml/document'

# Run once after flutter pub get (also safe to rerun). Keep the Flutter Runner
# project intact and add a real embedded WidgetKit target before CocoaPods.
bundle_id = ENV.fetch('BUNDLE_ID', 'com.ddyec.yiclass')
group_id = ENV.fetch('APP_GROUP', "group.#{bundle_id}")
abort 'Invalid bundle ID' unless bundle_id.match?(/\A[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+\z/)
abort 'Invalid App Group' unless group_id.match?(/\Agroup\.[A-Za-z0-9.-]+\z/)
project = Xcodeproj::Project.open('ios/Runner.xcodeproj')
runner = project.targets.find { |t| t.name == 'Runner' }
widget = project.targets.find { |t| t.name == 'ScheduleWidget' }
unless widget
  widget = project.new_target(:app_extension, 'ScheduleWidget', :ios, '15.0')
  sources = project.main_group.new_group('ScheduleWidget', 'ScheduleWidget')
  widget.source_build_phase.add_file_reference(sources.new_file('ScheduleWidget.swift'))
  sources.new_file('Info.plist')
  sources.new_file('ScheduleWidget.entitlements')
  runner.add_dependency(widget)
  embed = runner.new_copy_files_build_phase('Embed App Extensions')
  embed.dst_subfolder_spec = '13'
  embed.add_file_reference(widget.product_reference).settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
  # Embed before Flutter's thin phase so Xcode does not form a dependency cycle.
  runner.build_phases.delete(embed)
  thin_index = runner.build_phases.index { |phase| phase.respond_to?(:name) && phase.name == 'Thin Binary' }
  runner.build_phases.insert(thin_index || runner.build_phases.length, embed)
end
shared = project.main_group.groups.find { |g| g.name == 'Shared' } || project.main_group.new_group('Shared', 'Shared')
shared_file = shared.files.find { |f| f.path == 'SharedGroup.swift' } || shared.new_file('SharedGroup.swift')
[runner, widget].each do |target|
  unless target.source_build_phase.files_references.include?(shared_file)
    target.source_build_phase.add_file_reference(shared_file)
  end
end
project.build_configurations.each { |c| c.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0' }
[runner, widget].each do |target|
  target.build_configurations.each do |config|
    s = config.build_settings
    s['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    s['PRODUCT_BUNDLE_IDENTIFIER'] = target == runner ? bundle_id : "#{bundle_id}.ScheduleWidget"
    s['YICLASS_APP_GROUP'] = group_id
    s['CODE_SIGN_ENTITLEMENTS'] = target == runner ? 'Runner/Runner.entitlements' : 'ScheduleWidget/ScheduleWidget.entitlements'
    s['SWIFT_VERSION'] = '5.0'
    s['TARGETED_DEVICE_FAMILY'] = '1,2'
    if target == widget
      s['PRODUCT_NAME'] = 'ScheduleWidget'
      s['PRODUCT_MODULE_NAME'] = 'ScheduleWidget'
      s['INFOPLIST_FILE'] = 'ScheduleWidget/Info.plist'
      s['GENERATE_INFOPLIST_FILE'] = 'NO'
      s['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
      s['SKIP_INSTALL'] = 'YES'
      s['FLUTTER_BUILD_NAME'] = ENV.fetch('APP_VERSION', '2.4.0')
      s['FLUTTER_BUILD_NUMBER'] = ENV.fetch('BUILD_NUMBER', '1')
      s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
    end
  end
end
project.save
puts "Configured #{bundle_id}, #{bundle_id}.ScheduleWidget, #{group_id}"
