module Stall
  module AuthorizeDotNet
    class Gateway < Stall::Payments::Gateway
      register :authorize_dot_net

      class_attribute :account
      class_attribute :transaction_key
      class_attribute :md5_hash

      # Test or production mode, default to false, changes the payment
      # gateway target URL
      class_attribute :test_mode
      self.test_mode = !Rails.env.production?

      def self.test_mode=(value)
        OffsitePayments.mode = value ? :test : :production
        @test_mode = value
      end

      def self.request(cart)
        Request.new(cart)
      end

      def self.response(request)
        Response.new(request)
      end

      def self.fake_payment_notification_for(cart)
        Stall::AuthorizeDotNet::FakeGatewayPaymentNotification.new(cart)
      end

      class Request
        attr_reader :cart

        delegate :currency, to: :cart, allow_nil: true

        def initialize(cart)
          @cart = cart
        end

        def payment_form_partial_path
          'stall/authorize_dot_net/payment_form'
        end

        def gateway
          @gateway = Stall::AuthorizeDotNet::Gateway.new(cart)
        end
      end

      class Response
        attr_reader :request

        def initialize(request)
          @request = request
        end

        def rendering_options
          { nothing: true }
        end

        def success?
          @success ||= valid? && notification.complete?
        end

        def valid?
          puts "****************",
               "Acknowledge authorize payment with : #{ gateway.md5_hash }, #{ gateway.account } (#{ gateway.inspect })",
               "----------------",
               " Params : #{ params.inspect }"
               "****************"

          @valid ||= notification.acknowledge(gateway.md5_hash, gateway.account)
        end

        def notify
          cart.payment.pay! if success?
        end

        private

        def notification
          @notification ||=
            OffsitePayments::Integrations::AuthorizeNetSim::Notification.new(
              request.raw_post
            )
        end

        def cart
          @cart ||= Cart.find_by_reference(notification.invoice_num)
        end

        def gateway
          @gateway = Stall::AuthorizeDotNet::Gateway
        end
      end
    end
  end
end
