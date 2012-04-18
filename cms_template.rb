# Template for simple ActiveRecord based CMS with Padrino.
# First generate the project with all our favourite bits n bobs.
project :test => :minitest, :renderer => :erb, :stylesheet => :less, :script => :jquery, :orm => :activerecord, :bundle => true

SESSION_KEY_SETTING = "set :session_id, :_padrino_cms_session_id"

# Set up the session key, the cms filter and a couple of basic routes
#
# TODO: Might be simpler to copy the whole app.rb into place.
APP_INIT = <<-APP

  #{SESSION_KEY_SETTING}

  before do
    @current_account = CmsUtils.current_account(session[settings.session_id])
    @contents = Content.where(:path => CmsUtils.default_path(request))
  end

  get "/sitemap", :provides => [:html, :xml] do
    @title = "Sitemap"
    @pages = Content.where("path LIKE '/%'")
    render "sitemap"
  end
  
  # IMPORTANT That this route is the last in the app as :priority => :low does not seem to do what I expected.
  # Maybe I just need to RTFM again.
  #
  get "/*path", :priority => :low do
    render "main"
  end

APP
inject_into_file 'app/app.rb', APP_INIT, :after => "enable :sessions\n"

# Set a default date format
#
DATE_FORMAT = <<-DATE_FORMAT
  Time::DATE_FORMATS.merge!(:default => "%Y-%m-%d %H:%M")
DATE_FORMAT
inject_into_file 'config/boot.rb', DATE_FORMAT, :after => "Padrino.after_load do\n"

# Generate padrino admin.
#
puts "Generating Padrin Admin app."
generate :admin
rake "ar:create ar:migrate seed"

# Make the admin and main app share sessions. 
#
inject_into_file 'admin/app.rb', "  #{SESSION_KEY_SETTING}\n", :after => "enable  :sessions\n"

# Create contents model then append timestamps
#
puts "Creating contents model and migration."
generate :model, "content path:string account_id:integer title:string subtitle:string body:text status:string"
# TODO: Can this be done with the generate command above?
inject_into_file 'db/migrate/002_create_contents.rb',"      t.timestamps\n",:after => "t.string :status\n"
rake 'ar:migrate'

# Generate contents controller
#
puts "Creating contents controller."
generate :controller, "contents get:index get:show"
gsub_file('app/controllers/contents.rb', /^\s+\#\s+.*\n/,'')
CONTENT_INDEX_ROUTE = <<-CONTENT
      @contents = Content.all(:order => 'created_at desc')
      render 'contents/index'
CONTENT
CONTENT_SHOW_ROUTE = <<-CONTENT
      @content = Content.find_by_id(params[:id])
      render 'contents/show'
CONTENT
inject_into_file 'app/controllers/contents.rb', CONTENT_INDEX_ROUTE, :after => "get :index do\n"
inject_into_file 'app/controllers/contents.rb', CONTENT_SHOW_ROUTE, :after => "get :show do\n"

# Generate admin_page for content
#
puts "Creating contents administration pages."
generate :admin_page, "content"

# Update Content Model with Validations and Associations
#
puts "Creating associations."
CONTENT_MODEL = <<-CONTENT
  belongs_to :account
  validates_presence_of :path
  validates_presence_of :title
  validates_presence_of :body
CONTENT

inject_into_file 'models/content.rb', CONTENT_MODEL, :after => "ActiveRecord::Base\n"
rake 'ar:migrate'

# Update admin app controller for content
#
inject_into_file 'admin/controllers/contents.rb',"    @content.account = current_account\n",:after => "new(params[:content])\n"

# Include RSS Feed TODO: Need this?
#
inject_into_file 'app/controllers/contents.rb', ", :provides => [:html, :rss, :atom]", :after => "get :index"


# Copy the CmsUtils module the cms views and CKEditor files into place
#
%w( lib/cms_utils.rb 
    lib/uploader.rb
    app/views/layouts/application.erb 
    app/views/main.erb
    app/views/sitemap.erb
    app/views/sitemap.xml.erb
    app/views/contents/show.erb
    app/views/contents/index.erb
    admin/views/layouts/application.erb
    admin/controllers/images.rb
    public/stylesheets/application.css
    public/admin/stylesheets/base.css
    public/admin/javascripts
    public/admin/images
  ).each do |path|
 
  puts "Copying #{File.dirname(__FILE__)}/#{path} to #{destination_root}/#{path}"
  FileUtils.cp_r "#{File.dirname(__FILE__)}/#{path}", "#{destination_root}/#{path}"

end

IMAGE_UPLOAD_GEMS = <<-GEMS

# Gems needed for image upload
gem 'carrierwave'
gem 'mini_magick'
gem 'fog'

GEMS

puts "Adding required gems to Gemfile"
inject_into_file 'Gemfile', IMAGE_UPLOAD_GEMS, :after => "gem 'sqlite3'\n"

puts "Including CMS utility methods in contents_helper.rb"
HELPER_METHODS = <<-HELPER
 include CmsUtils
HELPER

inject_into_file 'app/helpers/contents_helper.rb', HELPER_METHODS, :after => ".helpers do\n"


#CONTENT_FORM_PATH_FIELD = <<-CONTENT
#  -if params[:path]
#    =f.hidden_field :path, :value => params[:path]
#  -else
#CONTENT

#inject_into_file 'admin/views/contents/_form.haml', CONTENT_FORM_PATH_FIELD, :before => "   =f.label :path"

get 'https://github.com/padrino/sample_blog/raw/master/public/stylesheets/reset.css', 'public/stylesheets/reset.css'
# get "https://github.com/padrino/sample_blog/raw/master/app/stylesheets/application.less", 'app/stylesheets/application.sass'
