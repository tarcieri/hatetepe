module Hatetepe
  class Prefork
    def self.run(server)
      prefork = new(server)
      fork {
        prefork.serve
      }
      prefork.manage
    end
  end
end
