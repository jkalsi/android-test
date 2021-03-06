module PageObjectModel
  module CalabashProxy
    require 'calabash-android/operations'
    include Calabash::Android::Operations
    include Logging

    # a monkey patch stub based on this suggestion, sadly they do not want to address it in calabash itself: https://github.com/calabash/calabash-ios/issues/531
    def embed(*)
      logger.error "Embed is a Cucumber method and is not available within the context of CalabashProxy"
    end
  end
end

module PageObjectModel
  class Element
    include Logging

    attr_reader :selector

    def initialize(selector)
      @selector = selector
    end

    private

    def calabash_proxy
      @calabash_proxy ||= Class.new.extend(PageObjectModel::CalabashProxy)
    end

    public

    def attributes
      query = calabash_proxy.query(selector)
      fail "Unable to locate element \##{selector}" if query.empty?
      query.first
    end

    def has_attribute?(attr)
      attributes.key?(attr)
    end

    def set(text) #an experimental method, as I am not sure we want to diverge from calabash operations API
      clear_text
      enter_text(text)
    end

    def set_checkbox(condition)
      query(:setChecked => condition)
    end

    def get_text
      query(:text)
    end

    def webview_text
      query(:textContent).first
    end

    def enabled?
      query(:enabled).first
    end

    def selected?
      query(:isSelected).first
    end

    def size
      query.size
    end

    alias_method :count, :size

    def with_text(text)
      puts "#{selector} text:'#{text}'"
    end

    #I would prefer this over the exists? for elements as there is a built in 'small' delay which caters for cases
    #where you have to wait for a transition or something to animate for a second or so.(i.e. search results)
    #the only drawback is that it will wait for the delay when you do something like...
    #drawer_menu.should_not be_visible , but it reads a lot better than drawer_memu.should_not exist.
    #it can be used with Rspec now as it returns true and false (and not nil or exception)
    def visible?
      calabash_proxy.when_element_exists(selector, timeout: 5, action: lambda { return true })
    rescue
      false
    end

    def exists? #a change to existing calabash operations API as well, but I am happy with extensions like this for the sake of proper ruby paradigm behind method names
      calabash_proxy.element_exists(selector)
    end

    #@examples:
    #
    #    my_element.touch --> calabash_proxy.touch(selector)
    #    my_field.enter_text("hello") --> calabash_proxy.enter_text(selector, "hello")
    #    my_field.text --> my_field.attributes['text']
    #    my_element.non_existing_method --> raise NoMethodError
    def method_missing(method_name, *args, &block)
      if calabash_proxy.respond_to?(method_name.to_sym)
        logger.debug %(Delegating method call \##{method_name}(#{args.join(', ')}) for selector "#{selector}" to calabash)
        calabash_proxy.send(method_name.to_sym, selector, *args, &block)
      elsif has_attribute?(method_name.to_s)
        logger.debug %(Fetching element attribute \##{method_name} for selector "#{selector}")
        attributes[method_name.to_s]
      else
        raise NoMethodError, %(undefined method '#{method_name}' for \##{self.class.inspect} with selector "#{selector}")
      end
    end
  end
end
