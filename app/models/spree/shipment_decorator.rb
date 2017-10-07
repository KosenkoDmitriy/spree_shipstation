Spree::Shipment.class_eval do
  scope :exportable, -> {
	joins(:order)
    .where('spree_shipments.state != ?', 'pending')
    .where("#{Spree::Order.table_name}.number not ilike 'D%'")
    .where("#{Spree::Order.table_name}.completed_at > ?", Time.new(2017, 6, 15))
  }

  def self.between(from, to)
    joins(:order).where('(spree_shipments.updated_at > ? AND spree_shipments.updated_at < ?) OR (spree_orders.updated_at > ? AND spree_orders.updated_at < ?)',from, to, from, to)
  end

  def variants_hash_for_export
    # call product assembly method, then combine each variant since Shipstation wants
    # each sku to appear only once
    line_items.each_with_object({}) do |line, memo|
      if line.product.assembly?
        if line.part_line_items.any?
          line.part_line_items.each do |pli|
            add_to_memo(memo, pli.variant, pli.proportional_unit_price, pli.quantity * line.quantity)
          end
        else
          line.variant.parts_variants.each do |pv|
            add_to_memo(memo, pv.part, pv.proportional_unit_price, pv.count)
          end
        end
      else
        add_to_memo(memo, line.variant, line.price, line.quantity)
      end
    end
  end

  def add_to_memo(memo, variant, price, quantity)
    if quantity > 0
      memo[variant] ||= { price: 0, quantity: 0 }
      memo[variant][:price] = (memo[variant][:price]*memo[variant][:quantity] + quantity * price) / (memo[variant][:quantity] + quantity)
      memo[variant][:quantity] += quantity
    end
  end
end
