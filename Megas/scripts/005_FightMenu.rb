#===============================================================================
# PIF's own fight menu checks ACTION (Z) as "cancel" before it checks it as
# "toggle Mega", so the Mega key backs out of the menu. While a Mega is
# possible, ACTION toggles Mega (BACK still cancels). EBDX's menu is fine.
#===============================================================================
class PokeBattle_Scene
  alias megas_pbFightMenu pbFightMenu unless method_defined?(:megas_pbFightMenu)
  def pbFightMenu(idxBattler, megaEvoPossible = false, &block)
    megas_pbFightMenu(idxBattler, megaEvoPossible) do |cmd|
      if cmd == -1 && megaEvoPossible && Input.trigger?(Input::ACTION) && !Input.trigger?(Input::BACK)
        cmd = -2   # same frame as the key press, so Input still shows which key it was
      end
      block.call(cmd)
    end
  end
end
