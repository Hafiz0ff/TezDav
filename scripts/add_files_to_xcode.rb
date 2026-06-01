#!/usr/bin/env ruby
# Add new design files to TezDav.xcodeproj
# Uses a workaround for FitDataProtocol consistency issue:
# saves the project as binary plist (Xcode reads it fine on next open).

gem_base = File.expand_path('~/.gem/ruby/2.6.0/gems')
Dir.glob("#{gem_base}/*/lib").each { |path| $LOAD_PATH.unshift(path) }

require 'xcodeproj'

project_path = '/Users/hafizov/Dav.TJ/TezDav.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'TezDav' }
abort "Target 'TezDav' not found" unless target

tezdav_group = project.main_group.find_subpath('TezDav', false)
abort "Group 'TezDav' not found" unless tezdav_group

files_to_add = [
  { path: 'TezDav/DesignSystem/Colors.swift',            group: 'DesignSystem' },
  { path: 'TezDav/DesignSystem/Typography.swift',        group: 'DesignSystem' },
  { path: 'TezDav/DesignSystem/ComponentStyles.swift',   group: 'DesignSystem' },
  { path: 'TezDav/DesignSystem/LiquidGlass.swift',       group: 'DesignSystem' },
  { path: 'TezDav/Components/ActivityCardView.swift',    group: 'Components' },
  { path: 'TezDav/Components/CustomTabBar.swift',        group: 'Components' },
  { path: 'TezDav/Dashboard/StoryFeedDashboardView.swift', group: 'Dashboard' }
]

project_root = '/Users/hafizov/Dav.TJ'
added_count = 0
skipped_count = 0

files_to_add.each do |entry|
  abs_path = File.join(project_root, entry[:path])
  unless File.exist?(abs_path)
    puts "  SKIP (missing on disk): #{entry[:path]}"
    skipped_count += 1
    next
  end

  already_in = project.files.any? { |f| f.real_path.to_s == abs_path }
  if already_in
    puts "  SKIP (already in project): #{entry[:path]}"
    skipped_count += 1
    next
  end

  # Find existing subgroup or create one inside TezDav/
  subgroup = tezdav_group.find_subpath(entry[:group], false)
  if subgroup.nil?
    subgroup = tezdav_group.new_group(entry[:group], entry[:group])
    puts "  CREATED group: TezDav/#{entry[:group]}"
  end

  file_ref = subgroup.new_reference(abs_path)
  target.add_file_references([file_ref])

  puts "  ADDED: #{entry[:path]}"
  added_count += 1
end

# Workaround for FitDataProtocol consistency issue:
# instead of calling project.save (which triggers ascii_plist_annotation
# for every build_file and crashes on orphaned references), write the
# pbxproj as XML plist using to_hash. Xcode rewrites it as ascii on next open.
pbxproj_path = File.join(project_path, 'project.pbxproj')
plist_data = project.to_hash

# Write as XML plist (Xcode reads XML plists fine for pbxproj)
require 'xcodeproj/plist'
Xcodeproj::Plist.write_to_path(plist_data, pbxproj_path)

puts ""
puts "Done. Added: #{added_count}, Skipped: #{skipped_count}"
puts "pbxproj saved as XML plist (Xcode will re-canonicalize on next open)."
