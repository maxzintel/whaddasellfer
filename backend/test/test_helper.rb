ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

    # Minitest 6 dropped minitest/mock. Temporarily replaces object.name with
    # `replacement`, which gets the original method as its first argument.
    def with_singleton_stub(object, name, replacement)
      original = object.method(name)
      object.define_singleton_method(name) do |*args, **kwargs, &block|
        replacement.call(original, *args, **kwargs, &block)
      end
      yield
    ensure
      object.singleton_class.remove_method(name)
    end

    # Every hash key anywhere in a parsed JSON tree.
    def all_keys(node)
      case node
      when Hash then node.keys + node.values.flat_map { |value| all_keys(value) }
      when Array then node.flat_map { |value| all_keys(value) }
      else []
      end
    end
  end
end
