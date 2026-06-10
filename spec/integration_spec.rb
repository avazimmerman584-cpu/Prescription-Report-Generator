# frozen_string_literal: true

require 'stringio'
require 'gifthealth/pharmacy_system'
require 'gifthealth/report'

RSpec.describe 'Pharmacy System Integration' do
  let(:input_data) do
    <<~INPUT
      Nick A created
      Mark B created
      Mark B filled
      Mark C filled
      Mark B returned
      John E created
      Mark B filled
      Mark B filled
      Paul D filled
      John E filled
      John E returned
    INPUT
  end

  let(:expected_output) do
    <<~OUTPUT
      John: 0 fills $-1 income
      Mark: 2 fills $9 income
      Nick: 0 fills $0 income
    OUTPUT
  end

  it 'correctly processes the sample data and produces the expected report' do
    pharmacy_system = Gifthealth::PharmacySystem.new
    input_stream = StringIO.new(input_data)

    pharmacy_system.process_stream(input_stream)

    output_stream = StringIO.new
    Gifthealth::Report.generate(pharmacy_system, output_stream)

    actual_lines = output_stream.string.strip.split('\n')
    expected_lines = expected_output.strip.split('\n')

    expect(actual_lines).to match_array(expected_lines)
  end

  it 'does not create an entry for a patient with no created events' do
    pharmacy_system = Gifthealth::PharmacySystem.new
    pharmacy_system.process_stream(StringIO.new('Paul D filled\n'))

    output_stream = StringIO.new
    Gifthealth::Report.generate(pharmacy_system, output_stream)

    expect(output_stream.string).not_to include('Paul')
  end

  let(:edge_case_input) do
    <<~INPUT
      Mark Ibuprofen filled
      Mark Ibuprofen returned
      Mark Ibuprofen created
      Mark Ibuprofen filled
      Mark Ibuprofen returned
      Mark Ibuprofen returned
    INPUT
  end

  let(:edge_case_expected_output) do
    <<~OUTPUT
      Mark: 0 fills $-1 income
    OUTPUT
  end

  it 'handles edge cases correctly' do
    pharmacy_system = Gifthealth::PharmacySystem.new
    input_stream = StringIO.new(edge_case_input)

    pharmacy_system.process_stream(input_stream)

    output_stream = StringIO.new
    Gifthealth::Report.generate(pharmacy_system, output_stream)

    actual_lines = output_stream.string.strip.split("\n")
    expected_lines = edge_case_expected_output.strip.split("\n")

    expect(actual_lines).to match_array(expected_lines)
  end
end
