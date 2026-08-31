import giolt/lustre/islands
import gleam/int
import gleam/option
import lustre/attribute
import lustre/effect
import lustre/element/html
import plinth/javascript/global

const max_count = 99

pub type Msg {
  ComponentConnected
  ParentChangedClass(class: String)
  CounterWentUp
  IntervalSetTimerId(global.TimerID)
}

pub type Model {
  Model(count: Int, timer_id: option.Option(global.TimerID), class: String)
}

pub fn init(_args) -> #(Model, effect.Effect(Msg)) {
  #(Model(count: 0, timer_id: option.None, class: ""), effect.none())
}

pub fn update(model: Model, msg: Msg) -> #(Model, effect.Effect(Msg)) {
  case msg {
    ParentChangedClass(class) -> #(Model(..model, class:), effect.none())
    CounterWentUp -> {
      case model.count {
        count if count == max_count -> {
          case model.timer_id {
            option.Some(timer_id) -> global.clear_interval(timer_id)
            option.None -> Nil
          }

          #(model, effect.none())
        }
        _ -> #(Model(..model, count: model.count + 1), effect.none())
      }
    }
    IntervalSetTimerId(timer_id) -> {
      #(Model(..model, timer_id: option.Some(timer_id)), effect.none())
    }
    ComponentConnected -> #(model, effect.none())
  }
}

pub fn view(model: Model) {
  html.span([attribute.id("countup"), attribute.class(model.class)], [
    html.text(int.to_string(model.count)),
  ])
}

pub fn component() {
  islands.create_component(
    init,
    update,
    view,
    [#("class", ParentChangedClass)],
    ComponentConnected,
  )
}

pub fn element(attrs: List(attribute.Attribute(Msg))) {
  islands.render_island(component, attrs, [], "countup", ComponentConnected)
}

pub fn main() {
  islands.register_island(component, "countup")
}
