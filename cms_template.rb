# Template for simple ActiveRecord based CMS.
# First generate the project with all our favourite bits n bobs.
project :test => :shoulda, :renderer => :haml, :stylesheet => :sass, :script => :jquery, :orm => :activerecord, :bundle => true

SESSION_KEY_SETTING = "set :session_id, :_padrino_cms_session_id"

# Set up the session key, the cms filter and a couple of basic routes
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

  get "/*path", :priority => :low do
    render "main"
  end

APP
inject_into_file 'app/app.rb', APP_INIT, :after => "enable :sessions\n"

# Generating padrino admin
generate :admin
rake "ar:create ar:migrate seed"

inject_into_file 'admin/app.rb', "  #{SESSION_KEY_SETTING}\n", :after => "enable  :sessions\n"

# Create contents model then
# append timestamps
generate :model, "content path:string title:string subtitle:string body:text status:string"
inject_into_file 'db/migrate/002_create_contents.rb',"      t.timestamps\n",:after => "t.string :status\n"
rake 'ar:migrate'

# Generating contents controller
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
inject_into_file 'app/controllers/contents.rb', ", :with => :id", :after => "get :show" # doesn't run?

# Generate admin_page for content
generate :admin_page, "content"

# Migrations to add account to content
generate :migration, "AddAccountToContent account_id:integer"

# Update Post Model with Validations and Associations
CONTENT_MODEL = <<-CONTENT
  belongs_to :account
  validates_presence_of :path
  validates_presence_of :title
  validates_presence_of :body
CONTENT
inject_into_file 'models/content.rb', CONTENT_MODEL, :after => "ActiveRecord::Base\n"
rake 'ar:migrate'

# Update admin app controller for content
inject_into_file 'admin/controllers/contents.rb',"    @content.account = current_account\n",:after => "new(params[:content])\n"

# Include RSS Feed
inject_into_file 'app/controllers/contents.rb', ", :provides => [:html, :rss, :atom]", :after => "get :index"

# Copy the CmsUtils module into place
get "https://github.com/steventux/padrino_cms_template/raw/master/lib/cms_utils.rb", "lib/cms_utils.rb"

# Copy the main view into place
get "https://github.com/steventux/padrino_cms_template/raw/master/app/views/main.haml", "app/views/main.haml"
get "https://github.com/steventux/padrino_cms_template/raw/master/app/views/sitemap.haml", "app/views/sitemap.haml"
get "https://github.com/steventux/padrino_cms_template/raw/master/app/views/sitemap.xml.haml", "app/views/sitemap.xml.haml"

# Get the FCKEditor
get "https://github.com/steventux/padrino_cms_template/raw/master/public/admin/javascripts", "public/admin/javascripts"

HELPER_METHODS = <<-HELPER
 include CmsUtils
HELPER

inject_into_file 'app/helpers/contents_helper.rb', HELPER_METHODS, :after => ".helpers do\n"

# Create index.haml
CONTENT_INDEX = <<-CONTENT
- @title = "Welcome"

- content_for :include do
  = feed_tag(:rss, url(:contents, :index, :format => :rss),:title => "RSS")
  = feed_tag(:atom, url(:contents, :index, :format => :atom),:title => "ATOM")

#contents= partial 'contents/content', :collection => @contents
CONTENT
create_file 'app/views/contents/index.haml', CONTENT_INDEX

# Create _content.haml
CONTENT_PARTIAL = <<-CONTENT
.content
  .title= link_to content.title, url_for(:contents, :show, :id => content)
  .date= time_ago_in_words(content.created_at || Time.now) + ' ago'
  .body= simple_format(content.body)
  .details
    .author Posted by \#{content.account.email}
CONTENT
create_file 'app/views/contents/_content.haml', CONTENT_PARTIAL

# Create show.haml
CONTENT_SHOW = <<-CONTENT
- @title = @content.title
#show
  .content
    .title= @content.title
    .date= time_ago_in_words(@content.created_at || Time.now) + ' ago'
    .body= simple_format(@content.body)
    .details
      .author Posted by \#{@content.account.email}
%p= link_to 'View all contents', url_for(:contents, :index)
CONTENT
create_file 'app/views/contents/show.haml', CONTENT_SHOW

APPLICATION = <<-LAYOUT
!!! Strict
%html
  %head
    %title= [@title, "Simple Padrino CMS"].compact.join(" | ")
    = stylesheet_link_tag 'reset', 'application'
    = javascript_include_tag 'jquery', 'application'
    = yield_content :include
  %body
    #header
      %h1 Simple Padrino CMS
      %ul.menu
        %li= link_to 'Content', url_for(:contents, :index)
    #container
      #main= yield
      #sidebar
        - form_tag url_for(:contents, :index), :method => 'get'  do
          Search for:
          = text_field_tag 'query', :value => params[:query]
          = submit_tag 'Search'
        %p Recent Contents
        %ul.bulleted
          %li Item 1 - Lorem ipsum dolorum itsum estem
          %li Item 2 - Lorem ipsum dolorum itsum estem
          %li Item 3 - Lorem ipsum dolorum itsum estem
        %p Categories
        %ul.bulleted
          %li Item 1 - Lorem ipsum dolorum itsum estem
          %li Item 2 - Lorem ipsum dolorum itsum estem
          %li Item 3 - Lorem ipsum dolorum itsum estem
        %p Latest Comments
        %ul.bulleted
          %li Item 1 - Lorem ipsum dolorum itsum estem
          %li Item 2 - Lorem ipsum dolorum itsum estem
          %li Item 3 - Lorem ipsum dolorum itsum estem
    #footer
      Copyright (c) 2009-2010 Padrino
LAYOUT
create_file 'app/views/layouts/application.haml', APPLICATION

CONTENT_FORM_PATH_FIELD = <<-CONTENT
  -if params[:path]
    =f.hidden_field :path, :value => params[:path]
  -else
CONTENT

inject_into_file 'admin/views/contents/_form.haml', CONTENT_FORM_PATH_FIELD, :before => "   =f.label :path"

get 'https://github.com/padrino/sample_blog/raw/master/public/stylesheets/reset.css', 'public/stylesheets/reset.css'
get "https://github.com/padrino/sample_blog/raw/master/app/stylesheets/application.sass", 'app/stylesheets/application.sass'
