class DatabaseFormExtension < Radiant::Extension
  version "0.2"
  description "Provides a page type for email contact and request forms and saves requests to a database (modified Mailer)."
  url "http://ubikorp.com/projects"

  define_routes do |map|
    map.connect 'admin/form_responses/:action/:id', :controller => 'admin/form_responses'
  end
  
  def activate
    admin.tabs.add "Form Responses", "/admin/form_responses", :before => "Layouts"
    DatabaseFormPage
  end
  
  def deactivate
    admin.tabs.remove "Form Responses"
  end
end
