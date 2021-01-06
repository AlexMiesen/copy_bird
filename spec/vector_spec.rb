require_relative '../vector'

RSpec.describe Vector do
  it 'can set itself' do
    v1 = Vector[1, 2]
    v2 = Vector[3, 4]
    v1.set!(v2)
    expect(v1).to eq(v2)
    expect(v1).not_to be(v2)
  end

  it 'does scalar multiplication' do
    expect(5 * Vector[1, 2]).to eq(Vector[5, 10])
  end

  it 'does vector addition' do
    expect(Vector[1, 2] + Vector[3, 4]).to eq(Vector[4, 6])
  end

  it 'does vector subtraction' do
    expect(Vector[1, 2] - Vector[3, 4]).to eq(Vector[-2, -2])
  end

  it 'does vector negation' do
    expect(-Vector[1, 2]).to eq(Vector[-1, -2])
  end
end
