require "eventmachine"

module EM::Deferrable
  def set_deferred_status_with_status_fix(status, *args)
    return if defined?(@deferred_status) && ![:unknown, status].include?(@deferred_status)
    set_deferred_status_without_status_fix status, *args
  end
  
  alias_method :set_deferred_status_without_status_fix, :set_deferred_status
  alias_method :set_deferred_status, :set_deferred_status_with_status_fix
end
