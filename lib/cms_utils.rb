module CmsUtils

  def cmsify contents=@contents, opts={}
    self.class.cmsify contents, opts
  end

  def self.cmsify(contents, opts)
    path = opts[:path] || "/"
    field = opts[:field] || "body"
    value = @contents.nil? ? '' : @contents.first.send(field)
    if @current_account and @current_account.role == "admin"
      if @contents.nil?
        # TODO : allow for templating of cms links
        value = "&nbsp;&nbsp;#{link_to '[add text]', '/admin/contents/new?path='+opts[:path]}"
      else
        value += "&nbsp;&nbsp;#{link_to '[edit]', '/admin/contents/edit/'+@contents.first.to_param}"
      end
    end
    value
  end

  def default_path request
    self.class.default_path request
  end

  # Returns the default key for the current request, this will be
  # request.route.path if present otherwise request.path
  #
  def self.default_path request
    raise "Unable to access current request." if request.nil?

    if request.route.class == HttpRouter::Route
      request.route.path
    else
      request.path_info
    end
  end
  
  def current_account session_id
    self.class current_account session_id
  end
  
  def self.current_account session_id
    @current_account ||= Account.find_by_id() if defined?(Account)
  end

end
