require 'spec_helper'

describe Spree::Shipment do
  context "between" do
    before do
      @active = []
      @dt1 = 1.day.ago
      @dt2 = 1.day.from_now
      @dt_now = Time.now

      Timecop.travel(@dt1) do
        @shipment1 = create(:shipment, order: create(:order))
      end

      Timecop.travel(@dt2) do
        @shipment2 = create(:shipment, order: create(:order))
      end

      # Old shipment thats order was recently updated..
      @order3 = create(:order, updated_at: @dt_now)
      Timecop.travel(1.week.ago) do
        @shipment3 = create(:shipment)
      end
      @shipment3.order = @order3
      @shipment3.save!
      @active << @shipment3
      # End Old shipment thats order was recently updated..

      @shipment4 = create(:shipment, order: create(:order))
      @shipment5 = create(:shipment, order: create(:order))

      # New shipments
      @active << @shipment4
      @active << @shipment5
    end

    # Get new shipments
    from = Time.now - 1.hour
    to = Time.now + 1.hour

    subject(:shipments) { Spree::Shipment.between(from, to) }
    specify { expect(shipments.size).to eq(@active.size) } # check the searching of the active shipments

    shipments2 = Spree::Shipment.where(updated_at: from..to)
    specify { expect(shipments2.size).to eq(@active.size) } # check the searching of the active shipments

    specify { expect(@active.size).to eq(3) } # check size of the @active shipments

    subject(:all_shipments) { Spree::Shipment.all }
    specify { expect(all_shipments.size).to eq(5) } # check the total shipments

  end

  context "exportable" do
    let!(:pending) { create_shipment(state: 'pending') }
    let!(:ready) { create_shipment(state: 'ready') }
    let!(:shipped) { create_shipment(state: 'shipped') }

    subject { Spree::Shipment.exportable }

    # specify { should have(2).shipments }
    specify { expect(subject.count).to eq(2) }

    specify { should include(ready) }
    specify { should include(shipped) }

    specify { should_not include(pending) }
  end

  context "shipped_email" do
    let(:shipment) { create_shipment(state: 'ready') }

    context "enabled" do
      it "sends email" do
        Spree::Config.send_shipped_email = true
        mail_message = double(Mail::Message)
        expect(Spree::ShipmentMailer).to receive(:shipped_email)
                                         .with(shipment.id)
                                         .and_return(mail_message)
        expect(mail_message).to receive(:deliver_later)

        shipment.ship!
      end
    end

    context "disabled" do
      it "doesnt send email" do
        Spree::Config.send_shipped_email = false
        expect(Spree::ShipmentMailer).not_to receive(:shipped_email)
        shipment.ship!
      end
    end
  end

  def create_shipment(options={})
    FactoryGirl.create(:shipment, options).tap do |shipment|
      shipment.update_column(:state, options[:state]) if options[:state]
      shipment.update_column(:updated_at, options[:updated_at]) if options[:updated_at]
    end
  end

end
