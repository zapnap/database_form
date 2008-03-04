require File.dirname(__FILE__) + '/../test_helper'

class DatabaseFormExtensionTest < Test::Unit::TestCase
  def test_initialization
    assert_equal File.join(File.expand_path(RAILS_ROOT), 'vendor', 'extensions', 'database_form'), DatabaseFormExtension.root
    assert_equal 'Database Form', DatabaseFormExtension.extension_name
  end

  def test_should_define_pages
    assert defined?(DatabaseFormPage)
  end
end
