require File.dirname(__FILE__) + '/test_helper'

require 'text_mate_mock'
require 'rails/rails_path'

class RailsPathTest < Test::Unit::TestCase
  def setup
    TextMate.line_number = '1'
    TextMate.column_number = '1'
    TextMate.project_directory = File.expand_path(File.dirname(__FILE__) + '/app_fixtures')
    @rp_controller = RailsPath.new(FIXTURE_PATH + '/app/controllers/user_controller.rb')
    @rp_controller_with_module = RailsPath.new(FIXTURE_PATH + '/app/controllers/admin/base_controller.rb')
    @rp_view = RailsPath.new(FIXTURE_PATH + '/app/views/user/new.rhtml')
    @rp_view_with_module = RailsPath.new(FIXTURE_PATH + '/app/views/admin/base/action.rhtml')
    @rp_fixture = RailsPath.new(FIXTURE_PATH + '/test/fixtures/users.yml')
    @rp_fixture_spec = RailsPath.new(FIXTURE_PATH + '/spec/fixtures/users.yml')
    @rp_wacky = RailsPath.new(FIXTURE_PATH + '/wacky/users.yml')
  end

  def test_rails_root
    assert_equal File.expand_path(File.dirname(__FILE__) + '/app_fixtures'), RailsPath.new.rails_root
  end

  def test_extension
    assert_equal "rb", @rp_controller.extension
    assert_equal "rhtml", @rp_view.extension
  end

  def test_file_type
    assert_equal :controller, @rp_controller.file_type
    assert_equal :view, @rp_view.file_type
    assert_equal :fixture, @rp_fixture.file_type
    assert_equal :fixture, @rp_fixture_spec.file_type
    assert_equal nil, @rp_wacky.file_type
  end

  def test_modules
    assert_equal [], @rp_controller.modules
    assert_equal ['admin'], @rp_controller_with_module.modules
    assert_equal [], @rp_view.modules
    assert_equal ['admin'], @rp_view_with_module.modules
    assert_equal [], @rp_fixture.modules
    assert_equal [], @rp_fixture_spec.modules
    assert_equal nil, @rp_wacky.modules
  end

  def test_controller_name
    rp = RailsPath.new(FIXTURE_PATH + '/app/models/person.rb')
    assert_equal "people", rp.controller_name
    rp = RailsPath.new(FIXTURE_PATH + '/app/models/user.rb')
    assert_equal "user", rp.controller_name
    rp = RailsPath.new(FIXTURE_PATH + '/app/models/users.rb')
    assert_equal "users", rp.controller_name
  end

  def test_controller_name_and_action_name_for_controller
    rp = RailsPath.new(FIXTURE_PATH + '/app/controllers/user_controller.rb')
    assert_equal "user", rp.controller_name
    assert_equal nil, rp.action_name

    TextMate.line_number = '3'
    rp = RailsPath.new(FIXTURE_PATH + '/app/controllers/user_controller.rb')
    assert_equal "user", rp.controller_name
    assert_equal "new", rp.action_name

    TextMate.line_number = '6'
    rp = RailsPath.new(FIXTURE_PATH + '/app/controllers/user_controller.rb')
    assert_equal "user", rp.controller_name
    assert_equal "create", rp.action_name
  end

  def test_controller_name_and_action_name_for_view
    rp = RailsPath.new(FIXTURE_PATH + '/app/views/user/new.rhtml')
    assert_equal "user", rp.controller_name # this was pre-2.0 behavior. s/b "users"
    assert_equal "new", rp.action_name
  end

  # Rails 2.x convention is for pluralized controllers
  def test_controller_name_and_action_name_for_2_dot_ooh_views
    rp = RailsPath.new(FIXTURE_PATH + '/app/views/users/new.html.erb')
    assert_equal "users", rp.controller_name
    assert_equal "new", rp.action_name
  end

  def test_controller_name_pluralization
    rp = RailsPath.new(FIXTURE_PATH + '/app/views/people/new.html.erb')
    assert_equal "people", rp.controller_name
  end

  def test_controller_name_suggestion_when_controller_absent
    rp = RailsPath.new(FIXTURE_PATH + '/app/views/people/new.html.erb')
    assert_equal "people", rp.controller_name
  end

  def test_respond_to_format
    current_file = RailsPath.new(FIXTURE_PATH + '/app/controllers/posts_controller.rb')
    TextMate.line_number = '14'
    assert_equal [13, 'js'], current_file.respond_to_format
  end

  def test_rails_path_for
    partners = [
      # Basic tests
      [FIXTURE_PATH + '/app/controllers/user_controller.rb', :helper, FIXTURE_PATH + '/app/helpers/user_helper.rb'],
      [FIXTURE_PATH + '/app/controllers/user_controller.rb', :javascript, FIXTURE_PATH + '/public/javascripts/user.js'],
      [FIXTURE_PATH + '/app/controllers/user_controller.rb', :functional_test, FIXTURE_PATH + '/test/functional/user_controller_test.rb'],
      [FIXTURE_PATH + '/app/helpers/user_helper.rb', :controller, FIXTURE_PATH + '/app/controllers/users_controller.rb'],
      [FIXTURE_PATH + '/app/models/user.rb', :controller, FIXTURE_PATH + '/app/controllers/users_controller.rb'],
      [FIXTURE_PATH + '/app/models/post.rb', :controller, FIXTURE_PATH + '/app/controllers/posts_controller.rb'],
      [FIXTURE_PATH + '/test/fixtures/users.yml', :model, FIXTURE_PATH + '/app/models/user.rb'],
      [FIXTURE_PATH + '/spec/fixtures/users.yml', :model, FIXTURE_PATH + '/app/models/user.rb'],
      [FIXTURE_PATH + '/app/controllers/user_controller.rb', :model, FIXTURE_PATH + '/app/models/user.rb'],
      [FIXTURE_PATH + '/test/fixtures/users.yml', :unit_test, FIXTURE_PATH + '/test/unit/user_test.rb'],
      [FIXTURE_PATH + '/app/models/user.rb', :fixture, FIXTURE_PATH + '/test/fixtures/users.yml'],
      # With modules
      [FIXTURE_PATH + '/app/controllers/admin/base_controller.rb', :helper, FIXTURE_PATH + '/app/helpers/admin/base_helper.rb'],
      [FIXTURE_PATH + '/app/controllers/admin/inside/outside_controller.rb', :javascript, FIXTURE_PATH + '/public/javascripts/admin/inside/outside.js'],
      [FIXTURE_PATH + '/app/controllers/admin/base_controller.rb', :functional_test, FIXTURE_PATH + '/test/functional/admin/base_controller_test.rb'],
      [FIXTURE_PATH + '/app/helpers/admin/base_helper.rb', :controller, FIXTURE_PATH + '/app/controllers/admin/base_controller.rb'],
    ]
    # TODO Add [posts.yml, :model, post.rb]
    for pair in partners
      assert_equal RailsPath.new(pair[2]), RailsPath.new(pair[0]).rails_path_for(pair[1])
    end

    # Test controller to view
    ENV['RAILS_VIEW_EXT'] = nil
    TextMate.line_number = '6'
    current_file = RailsPath.new(FIXTURE_PATH + '/app/controllers/user_controller.rb')
    assert_equal RailsPath.new(FIXTURE_PATH + '/app/views/user/create.html.erb'), current_file.rails_path_for(:view)

    # 2.0 plural controllers
    current_file = RailsPath.new(FIXTURE_PATH + '/app/controllers/users_controller.rb')
    assert_equal RailsPath.new(FIXTURE_PATH + '/app/views/users/create.html.erb'), current_file.rails_path_for(:view)

    TextMate.line_number = '3'
    current_file = RailsPath.new(FIXTURE_PATH + '/app/controllers/user_controller.rb')
    assert_equal RailsPath.new(FIXTURE_PATH + '/app/views/user/new.rhtml'), current_file.rails_path_for(:view)

    # 2.0 plural controllers
    current_file = RailsPath.new(FIXTURE_PATH + '/app/controllers/users_controller.rb')
    assert_equal RailsPath.new(FIXTURE_PATH + '/app/views/users/new.html.erb'), current_file.rails_path_for(:view)

    # Test view to controller
    current_file = RailsPath.new(FIXTURE_PATH + '/app/views/user/new.html.erb')
    assert_equal RailsPath.new(FIXTURE_PATH + '/app/controllers/users_controller.rb'), current_file.rails_path_for(:controller)

    # 2.0 plural controllers
    current_file = RailsPath.new(FIXTURE_PATH + '/app/views/users/new.html.erb')
    assert_equal RailsPath.new(FIXTURE_PATH + '/app/controllers/users_controller.rb'), current_file.rails_path_for(:controller)

    ENV['RAILS_VIEW_EXT'] = nil
    # view defaults from respond_to block
    challenges = [
      [11, 'no_existing_views.html.erb'],
      [12, 'no_existing_views.html.erb'],
      [13, 'no_existing_views.js.rjs'],
      [14, 'no_existing_views.js.rjs'],
      [15, 'no_existing_views.js.rjs'],
      [16, 'no_existing_views.xml.builder'],
      [17, 'no_existing_views.wacky.erb'],
      [18, 'no_existing_views.wacky.erb'],

      [22, 'existing_views.html.erb'],
      [23, 'existing_views.html.erb'],
      [24, 'existing_views.js.rjs'],
      [25, 'existing_views.js.rjs'],
      [26, 'existing_views.js.rjs'],
      [27, 'existing_views.xml.builder'],
      [28, 'existing_views.wacky.erb'],
      [28, 'existing_views.wacky.erb'],
    ]
    challenges.each do |line, expected|
      TextMate.line_number = line.to_s
      current_file = RailsPath.new(FIXTURE_PATH + '/app/controllers/users_controller.rb')
      assert_equal(
        RailsPath.new(FIXTURE_PATH + '/app/views/users/' + expected),
        current_file.rails_path_for(:view),
        "Mismatch for line #{line}, should be #{expected}"
      )
    end

    # test wacky
    assert_equal(nil, 
                 @rp_wacky.rails_path_for(:controller), 
                 "wacky/wackier.rb has no associations") 
  end

  def test_file_parts
    current_file = RailsPath.new(FIXTURE_PATH + '/app/views/users/new.html.erb')
    assert_equal(FIXTURE_PATH + '/app/views/users/new.html.erb', current_file.filepath)
    pathname, basename, content_type, extension = current_file.parse_file_parts
    assert_equal(FIXTURE_PATH + '/app/views/users', pathname)
    assert_equal('new', basename)
    assert_equal('html', content_type)
    assert_equal('erb', extension)

    current_file = RailsPath.new(FIXTURE_PATH + '/app/views/user/new.rhtml')
    pathname, basename, content_type, extension = current_file.parse_file_parts
    assert_equal(FIXTURE_PATH + '/app/views/user', pathname)
    assert_equal('new', basename)
    assert_equal(nil, content_type)
    assert_equal('rhtml', extension)
  end

  def test_new_rails_path_has_parts
    current_file = RailsPath.new(FIXTURE_PATH + '/app/views/users/new.html.erb')
    assert_equal(FIXTURE_PATH + '/app/views/users/new.html.erb', current_file.filepath)
    assert_equal(FIXTURE_PATH + '/app/views/users', current_file.path_name)
    assert_equal('new', current_file.file_name)
    assert_equal('html', current_file.content_type)
    assert_equal('erb', current_file.extension)
  end

  def test_best_match
    assert_equal(nil, RailsPath.new(FIXTURE_PATH + '/config/boot.rb').best_match)
    assert_equal(:functional_test, RailsPath.new(FIXTURE_PATH + '/app/controllers/posts_controller.rb').best_match)
    assert_equal(:model, RailsPath.new(FIXTURE_PATH + '/app/controllers/users_controller.rb').best_match)
    assert_equal(:functional_test, RailsPath.new(FIXTURE_PATH + '/app/controllers/admin/base_controller.rb').best_match)

    TextMate.line_number = '3' # edit action
    assert_equal(:view, RailsPath.new(FIXTURE_PATH + '/app/controllers/admin/base_controller.rb').best_match)
    TextMate.line_number = '0'

    assert_equal(:controller, RailsPath.new(FIXTURE_PATH + '/app/views/users/new.html.erb').best_match)
    assert_equal(:controller, RailsPath.new(FIXTURE_PATH + '/app/views/user/new.rhtml').best_match)
    assert_equal(:controller, RailsPath.new(FIXTURE_PATH + '/app/views/admin/base/action.html.erb').best_match)
    assert_equal(:model, RailsPath.new(FIXTURE_PATH + '/app/views/notifier/forgot_password.html.erb').best_match)
    assert_equal(:controller, RailsPath.new(FIXTURE_PATH + '/app/views/books/new.haml').best_match)
  end

  def test_wants_haml
    begin
      assert_equal false, @rp_view.wants_haml
      haml_fixture_path = File.expand_path(File.dirname(__FILE__) + '/fixtures')
      TextMate.project_directory = haml_fixture_path
      assert_equal true, RailsPath.new(haml_fixture_path + '/app/views/posts/index.html.haml').wants_haml
    ensure
      TextMate.project_directory = File.expand_path(File.dirname(__FILE__) + '/app_fixtures')
    end
  end

  def test_haml
    begin
      haml_fixture_path = File.expand_path(File.dirname(__FILE__) + '/fixtures')
      TextMate.project_directory = haml_fixture_path

      assert_equal [], RailsPath.new(haml_fixture_path + '/public/stylesheets/sass/posts.sass').modules
      assert_equal ["admin"], RailsPath.new(haml_fixture_path + '/public/stylesheets/sass/admin/posts.sass').modules

      # Going from controller to view
      current_file = RailsPath.new(haml_fixture_path + '/app/controllers/posts_controller.rb')
      TextMate.line_number = '2'
      assert_equal RailsPath.new(haml_fixture_path + '/app/views/posts/new.html.haml'), current_file.rails_path_for(:view)

      current_file = RailsPath.new(haml_fixture_path + '/app/controllers/posts_controller.rb')
      TextMate.line_number = '12'
      assert_equal RailsPath.new(haml_fixture_path + '/app/views/posts/index.html.haml'), current_file.rails_path_for(:view)

      current_file = RailsPath.new(haml_fixture_path + '/app/controllers/posts_controller.rb')
      TextMate.line_number = '13'
      assert_equal RailsPath.new(haml_fixture_path + '/app/views/posts/index.xml.builder'), current_file.rails_path_for(:view)

      current_file = RailsPath.new(haml_fixture_path + '/app/controllers/posts_controller.rb')
      TextMate.line_number = '14'
      assert_equal RailsPath.new(haml_fixture_path + '/app/views/posts/index.js.rjs'), current_file.rails_path_for(:view)

      current_file = RailsPath.new(haml_fixture_path + '/app/controllers/posts_controller.rb')
      TextMate.line_number = '15'
      assert_equal RailsPath.new(haml_fixture_path + '/app/views/posts/index.wacky.haml'), current_file.rails_path_for(:view)

      # Going from view to controller
      current_file = RailsPath.new(haml_fixture_path + '/app/views/posts/index.html.haml')
      assert_equal RailsPath.new(haml_fixture_path + '/app/controllers/posts_controller.rb'), current_file.rails_path_for(:controller)

      # Going from view to stylesheet
      current_file = RailsPath.new(haml_fixture_path + '/app/views/posts/index.html.haml')
      assert_equal RailsPath.new(haml_fixture_path + '/public/stylesheets/sass/posts.sass'), current_file.rails_path_for(:stylesheet)

      # Going from stylesheet to helper
      current_file = RailsPath.new(haml_fixture_path + '/public/stylesheets/sass/posts.sass')
      assert_equal RailsPath.new(haml_fixture_path + '/app/helpers/posts_helper.rb'), current_file.rails_path_for(:helper)

    ensure
      TextMate.project_directory = File.expand_path(File.dirname(__FILE__) + '/app_fixtures')
    end
  end

end