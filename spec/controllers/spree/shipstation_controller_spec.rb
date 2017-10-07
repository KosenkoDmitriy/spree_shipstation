require 'spec_helper'

describe Spree::ShipstationController, type: :controller do

  before do
    # controller.stub(check_authorization: false, spree_current_user: FactoryGirl.create(:user)) # TODO: uncomment and fix it
    # controller.stub(:shipnotify)
    @request.accept = 'application/xml'
  end


  context "logged in" do
    before { login }

    context "export" do
      let(:shipments) { double(:shipments) }

      describe "record retrieval" do
        before do
          Spree::Shipment.stub_chain(:exportable, :between).with(Time.new(2013, 12, 31, 8, 0, 0, "+00:00"),
                                                                 Time.new(2014, 1, 13, 23, 0, 0, "+00:00"))
              .and_return(shipments)
          shipments.stub_chain(:page, :per).and_return(:some_shipments)

          get :export, start_date: '12/31/2013 8:00', end_date: '1/13/2014 23:00', use_route: :spree
        end

        specify { expect(response).to be_success }
        specify { expect(response).to have_http_status(200) }
        specify { expect(assigns(:shipments)).to eq(:some_shipments) }
      end

      describe "XML output" do
        render_views

        let(:order) { create(:order_ready_to_ship) }
        let(:shipment) { order.shipments.first }

        before(:each) do
          order.update_column(:updated_at, "2014-01-07")
          shipment.update_column(:updated_at, "2014-01-07")
        end

        it "renders xml including the shipment number as OrderNumber by default" do
          get :export, start_date: '12/31/2013 8:00', end_date: '1/13/2014 23:00', use_route: :spree
          expect(response.body).to include("<OrderNumber>#{shipment.number}</OrderNumber>")
        end
        it "adds the orderID as custom field 1" do
          get :export, start_date: '12/31/2013 8:00', end_date: '1/13/2014 23:00', use_route: :spree
          expect(response.body).to include("<CustomField1>#{order.number}</CustomField1>")
        end

        context "with custom fields defined on the order" do
          before(:each) do
            module ShipstationCustom
              def shipstation_custom_field_1
                "custom1"
              end

              def shipstation_custom_field_2
                "custom2"
              end

              def shipstation_custom_field_3
                "custom3"
              end
            end

            Spree::Order.class_eval do
              include ShipstationCustom
            end
          end

          it "honors custom fields defined on the order class" do
            get :export, start_date: '12/31/2013 8:00', end_date: '1/13/2014 23:00', use_route: :spree
            expect(response.body).to include("<CustomField1>custom1</CustomField1>")
            expect(response.body).to include("<CustomField2>custom2</CustomField2>")
            expect(response.body).to include("<CustomField3>custom3</CustomField3>")
          end
        end

        context "with gift wrapping" do
          before(:each) do
            module GiftWrapExtension
              def gift?
                true
              end

              def gift_wrapping_message
                "happy birthday"
              end
            end

            Spree::Order.class_eval do
              include GiftWrapExtension
            end
          end

          it "honors custom fields defined on the order class" do
            get :export, start_date: '12/31/2013 8:00', end_date: '1/13/2014 23:00', use_route: :spree
            expect(response.body).to include("<Gift>true</Gift>")
            expect(response.body).to include("<GiftMessage>happy birthday</GiftMessage>")
          end
        end
      end
    end

    context "shipnotify" do
      let(:notice) { double(:notice) }

      before do
        Spree::ShipmentNotice.should_receive(:new)
            .with(hash_including(order_number: 'S12345'))
            .and_return(notice)
      end

      context "shipment found" do
        before do
          notice.should_receive(:apply).and_return(true)

          post :shipnotify, order_number: 'S12345', use_route: :spree
        end

        # specify { response.should be_success }
        # specify { response.body.should =~ /success/ }

        specify { expect(response).to be_success }
        # specify { expect(response.body).to match(/success/) }
        specify { expect(response).to render_template("shipnotify") }
      end

      context "shipment not found" do
        before do
          notice.should_receive(:apply).and_return(false)
          notice.should_receive(:error).and_return("failed")

          post :shipnotify, order_number: 'S12345', use_route: :spree
        end

        # specify { response.code.should == '400' }
        # specify { response.body.should =~ /failed/ }

        specify { expect(response.code).to eq('400') }
        # specify { expect(response.body).to match(/failed/) }
        specify { expect(response).to render_template("shipnotify") }
      end
    end

    it "doesnt know unknown" do
      expect { post :unknown, use_route: :spree }.to raise_error(AbstractController::ActionNotFound)
    end
  end

  context "not logged in" do
    it "returns error" do
      get :export, use_route: :spree

      #response.code.should == '401'
      expect(response.code).to eq('401')
    end
  end

  def login
    user, pw = 'mario', 'lemieux'
    config(username: user, password: pw)
    request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials(user, pw)
  end

  def config(options = {})
    options.each do |k, v|
      Spree::Config.send("shipstation_#{k}=", v)
    end
  end
end
