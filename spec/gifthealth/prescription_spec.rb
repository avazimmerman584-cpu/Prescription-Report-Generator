# frozen_string_literal: true

require 'gifthealth/prescription'

RSpec.describe Gifthealth::Prescription do
  subject(:prescription) { described_class.new('DrugX') }

  it { is_expected.to have_attributes(drug_name: 'DrugX', fill_count: 0) }
  it { is_expected.not_to be_created }

  describe '#create' do
    it 'marks the prescription as created' do
      prescription.create
      expect(prescription).to be_created
    end
  end

  describe '#fill' do
    context 'when prescription is not created' do
      it 'does not increment fill count' do
        expect { prescription.fill }.not_to change(prescription, :fill_count)
      end

      it 'returns false' do
        expect(prescription.fill).to be false
      end
    end

    context 'when prescription is created' do
      before { prescription.create }

      it 'increments the fill count' do
        expect { prescription.fill }.to change(prescription, :fill_count).by(1)
      end

      it 'returns true' do
        expect(prescription.fill).to be true
      end
    end
  end

  describe '#return_fill' do
    before { prescription.create }

    context 'when prescription has not been filled' do
      it 'does not change the fill count' do
        expect { prescription.return_fill }.not_to change(prescription, :fill_count)
      end

      it 'returns false' do
        expect(prescription.return_fill).to be false
      end
    end

    context 'when prescription has been filled' do
      before { prescription.fill }

      it 'decrements the fill count' do
        expect { prescription.return_fill }.to change(prescription, :fill_count).by(-1)
      end

      it 'returns true' do
        expect(prescription.return_fill).to be true
      end
    end

    context 'when trying to return more than filled' do
      before do
        prescription.fill
        prescription.return_fill
      end

      it 'does not make the fill count negative' do
        expect { prescription.return_fill }.not_to change(prescription, :fill_count)
        expect(prescription.fill_count).to eq(0)
      end

      it 'returns false' do
        expect(prescription.return_fill).to be false
      end
    end
  end
end
