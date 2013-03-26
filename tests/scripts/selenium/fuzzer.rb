require 'debugger'
require 'selenium-webdriver'
require_relative 'selenium_adapter'

NUM_EDITS = 500
ALPHABET = "abcdefghijklmnopqrstuvwxyz"

################################################################################
# Helpers for generating random edits
################################################################################
def js_get_random_delta(driver, doc_delta)
  driver.switch_to.default_content
  return driver.execute_script("return window.Tandem.DeltaGen.getRandomDelta.apply(window.Tandem.DeltaGen, arguments)",
    doc_delta,
    ALPHABET,
    1)
  driver.switch_to.frame(driver.find_element(:tag_name, "iframe"))
end

def js_get_test_delta_0(driver)
  driver.switch_to.default_content
  test_delta = driver.execute_script(
    "return new window.Tandem.Delta(1, 2, [new window.Tandem.InsertOp('a'), new window.Tandem.RetainOp(0, 1)])"
  )
  driver.switch_to.frame(driver.find_element(:tag_name, "iframe"))
  return test_delta
end

def js_get_test_delta(driver)
  driver.switch_to.default_content
  test_delta = driver.execute_script(
    "return new window.Tandem.Delta(2, 2, [new window.Tandem.RetainOp(0, 1, {bold: true}), new window.Tandem.RetainOp(1, 2)])"
  )
  driver.switch_to.frame(driver.find_element(:tag_name, "iframe"))
  return test_delta
end

################################################################################
# Helpers
################################################################################
def check_consistency(driver, doc_delta, random_delta)
  writer_delta = driver.execute_script "return parent.writer.getDelta().toString();"
  new_delta = driver.execute_script "return arguments[0].compose(arguments[1])", doc_delta, random_delta
  raise "Writer: #{writer_delta}\nReader: #{reader_delta}" unless writer_delta == reader_delta
  doc_delta = writer_delta # XXX: Fix reference
end

def js_get_doc_delta(driver)
  doc_delta = driver.execute_script "return parent.writer.getDelta()"
end

################################################################################
# WebDriver setup
################################################################################
puts "Usage: ruby _browserdriver_ _editor_url_" unless ARGV.length == 2
browserdriver = ARGV[0].to_sym
editor_url = ARGV[1]
driver = Selenium::WebDriver.for browserdriver
driver.manage.timeouts.implicit_wait = 10
driver.get editor_url
editors = driver.find_elements(:class, "editor-container")
writer, reader = editors
driver.switch_to.frame(driver.find_element(:tag_name, "iframe"))
writer = driver.find_element(:class, "editor")
adapter = SeleniumAdapter.new driver, writer

################################################################################
# Fuzzer logic
################################################################################
doc_delta = js_get_doc_delta(driver)
first_delta = js_get_test_delta_0(driver)
adapter.apply_delta(first_delta)
second_delta = js_get_test_delta(driver)
adapter.apply_delta(second_delta)
NUM_EDITS.times do |i|
   random_delta = js_get_random_delta(driver, doc_delta)
   puts i if i % 10 == 0
   adapter.apply_delta(random_delta)
   check_consistency(driver, doc_delta, random_delta)
end