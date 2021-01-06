Vector = Struct.new(:x, :y) do
  def set!(other)
    self.x = other.x
    self.y = other.y
    self
  end

  def +(other)
    Vector[x + other.x, y + other.y]
  end

  def -(other)
    Vector[x - other.x, y - other.y]
  end

  def *(scalar)
    Vector[x * scalar, y * scalar]
  end

  def -@
    Vector[-x, -y]
  end

  def coerce(left)
    [self, left]
  end
end
