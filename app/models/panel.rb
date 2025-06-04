class Panel < ApplicationRecord
  belongs_to :board
  # 属性
  #  - index: 1～9
  #  - state: nil / "X" / "O"
end
