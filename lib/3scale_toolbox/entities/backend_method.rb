module ThreeScaleToolbox
  module Entities
    class BackendMethod
      VALID_PARAMS = %w[friendly_name system_name description].freeze
      public_constant :VALID_PARAMS

      class << self
        def create(backend:, parent_id:, attrs:)
          method = backend.remote.create_backend_method(backend.id, parent_id,
                                                        Helper.filter_params(VALID_PARAMS, attrs))
          if (errors = method['errors'])
            raise ThreeScaleToolbox::ThreeScaleApiError.new('Backend Method has not been created',
                                                            errors)
          end

          new(id: method.fetch('id'), parent_id: parent_id, backend: backend, attrs: method)
        end

        # ref can be system_name or method_id
        def find(backend:, parent_id:, ref:)
          new(id: ref, parent_id: parent_id, backend: backend).tap(&:attrs)
        rescue ThreeScaleToolbox::InvalidIdError, ThreeScale::API::HttpClient::NotFoundError
          find_by_system_name(backend: backend, parent_id: parent_id, system_name: ref)
        end

        def find_by_system_name(backend:, parent_id:, system_name:)
          backend.methods(parent_id).find { |m| m.system_name == system_name }
        end
      end

      attr_reader :id, :parent_id, :backend, :remote

      def initialize(id:, parent_id:, backend:, attrs: nil)
        @id = id.to_i
        @backend = backend
        @parent_id = parent_id
        @remote = backend.remote
        @attrs = process_attrs(attrs)
      end

      def attrs
        @attrs ||= process_attrs(method_attrs)
      end

      def system_name
        @attrs['system_name']
      end

      def friendly_name
        @attrs['friendly_name']
      end

      def update(m_attrs)
        new_attrs = remote.update_backend_method(backend.id, parent_id, id,
                                                 Helper.filter_params(VALID_PARAMS, m_attrs))
        if (errors = new_attrs['errors'])
          raise ThreeScaleToolbox::ThreeScaleApiError.new('Backend Method has not been updated',
                                                          errors)
        end

        # update current attrs
        @attrs = process_attrs(new_attrs)
      end

      def delete
        remote.delete_backend_method backend.id, parent_id, id
      end

      private

      def process_attrs(metric_attrs)
        return if metric_attrs.nil?

        # system_name: my_metric_02.45498 -> system_name: my_metric_02
        metric_attrs.merge('system_name' => metric_attrs.fetch('system_name', '').partition('.').first)
      end

      def method_attrs
        raise ThreeScaleToolbox::InvalidIdError if id.zero?

        method = remote.backend_method backend.id, parent_id, id
        if (errors = method['errors'])
          raise ThreeScaleToolbox::ThreeScaleApiError.new('Backend method not read', errors)
        end

        method
      end
    end
  end
end
