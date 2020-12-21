Given /^I have hospitals$/ do |table|
  table.hashes.each do |hash|
    FactoryBot.create(:hospital, hash)
  end
end
