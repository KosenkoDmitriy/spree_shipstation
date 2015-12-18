module Spree
  class ShipmentNotice
    attr_reader :error

    def initialize(params)
      @number   = params[:order_number]
      @tracking = params[:tracking_number]
    end

    def apply
      locate ? update : not_found
    rescue => e
      handle_error(e)
    end

    private

    def locate
      @shipment = @order = nil
      if Spree::Config.shipstation_number == :order
        @order = Spree::Order.find_by_number(@number)
        @shipment = @order.try(:shipments).try(:first)
      else
        @shipment = Spree::Shipment.find_by_number(@number)
        @order = @shipment.try(:order)
      end
      @shipment.present? && @order.present?
    end

    def update
      @shipment.update_attribute(:tracking, @tracking)

      unless @shipment.shipped?
        @shipment.reload.update_attribute(:state, 'shipped')
        @shipment.inventory_units.each &:ship!
        @shipment.touch :shipped_at
      end
      @order.shipment_state = 'shipped'
      @order.save!

      true
    end

    def not_found
      @error = I18n.t(:shipment_not_found, number: @number)
      false
    end
    
    def handle_error(error)
      Rails.logger.error(error)
      @error = I18n.t(:import_tracking_error, error: error.to_s)
      false
    end
  end
end
