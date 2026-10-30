# Password must match HostAppGate::PASSWORD in script/host_app_gate/gate.rb.
User.find_or_create_by!(email_address: "admin@example.com") do |user|
  user.password = "password123456"
  user.admin = true
end

User.find_or_create_by!(email_address: "member@example.com") do |user|
  user.password = "password123456"
  user.admin = false
end

[
  ["Blue Mug", :active, "kitchen", 12.5],
  ["Red Mug", :draft, "kitchen", 11.0],
  ["Green Teapot", :active, "kitchen", 39.9],
  ["Steel Kettle", :archived, "kitchen", 54.0],
  ["Paper Filters", :active, "office", 4.25],
  ["White Cup", :active, "garden", 6.0],
].each do |name, status, category, price|
  Product.find_or_create_by!(name: name) do |product|
    product.status = status
    product.category = category
    product.price = price
  end
end
