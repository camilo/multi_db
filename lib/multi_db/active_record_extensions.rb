module MultiDb
  module ActiveRecordExtensions
    def self.included(base)
      base.send :include, InstanceMethods
      base.send :extend, ClassMethods
      base.cattr_accessor :connection_proxy
      # handle subclasses which were defined by the framework or plugins
      base.hijack_connection
      base.send(:descendants).each do |child|
        child.hijack_connection
      end
    end

    module InstanceMethods
      def reload(options = nil)
        self.connection_proxy.with_master { super }
      end
    end

    module ClassMethods
      # Make sure transactions always switch to the master
      def transaction(options = {}, &block)
        if self.connection.kind_of?(ConnectionProxy)
          super
        else
          self.connection_proxy.with_master { super }
        end
      end

      # make caching always use the ConnectionProxy
      def cache(&block)
        if ActiveRecord::Base.configurations.blank?
          yield
        else
          self.connection_proxy.cache(&block)
        end
      end

      def inherited(child)
        super
        child.hijack_connection
      end

      def hijack_connection
        if name == "ReadonlyDatabase"
          logger.info "[MULTIDB] \x1b[31mNOT\x1b[0m hijacking connection for #{self.to_s}" if logger
          class << self
            def connection
              self.retrieve_connection
            end
          end
        else
          logger.info "[MULTIDB] hijacking connection for #{self.to_s}" if logger
          class << self
            def connection
              self.connection_proxy.establish_initial_connection
            end
          end
        end
      end
    end
  end
end
