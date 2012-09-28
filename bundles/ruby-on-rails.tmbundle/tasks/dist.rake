desc "Build bundle archive for distribution"
task :dist do
  bundle = 'Ruby\ on\ Rails.tmbundle'
  bundle_src = APP_ROOT
  bundle_dist = "website/dist"
  FileUtils.mkdir_p bundle_dist
  bundle_file = "#{bundle_dist}/#{bundle}.tar.gz"
  sh %{tar zcvf #{bundle_file}  --exclude .git --exclude #{bundle_file} .}
end