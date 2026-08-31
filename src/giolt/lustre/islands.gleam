import gleam/list
import gleam/string
import lustre
import lustre/attribute
import lustre/component
import lustre/effect.{type Effect}
import lustre/element
import lustre/element/html

pub fn render_island(
  component component: fn() -> lustre.App(Nil, model, msg),
  initial_attributes initial_attrs: List(attribute.Attribute(msg)),
  children children: List(element.Element(Nil)),
  tag tag: String,
  on_connected_msg on_connected_msg: msg,
) -> element.Element(Nil) {
  let children =
    children
    |> list.map(fn(el) { element.map(el, fn(_) { on_connected_msg }) })

  let component = case lustre.is_browser() {
    True -> element.element("island-" <> tag, initial_attrs, children)
    False ->
      component.prerender(
        component(),
        "island-" <> tag,
        initial_attrs,
        children,
      )
  }

  element.fragment([
    element.map(component, fn(_) { Nil }),
    html.script(
      [
        attribute.type_("module"),
      ],
      "import { main } from \"/_islands/${script}\"; main()"
        |> string.replace("${script}", string.replace(tag, "-", "_") <> ".js"),
    ),
  ])
}

@external(javascript, "./islands_ffi.mjs", "is_element_registered")
fn is_element_registered(_name: String) -> Bool {
  False
}

pub fn register_island(app: fn() -> lustre.App(Nil, model, msg), tag: String) {
  case is_element_registered("island-" <> tag) {
    True -> Nil
    False -> {
      let assert Ok(_) = lustre.register(app(), "island-" <> tag)
      Nil
    }
  }
}

pub fn create_component(
  init init: fn(Nil) -> #(model, Effect(msg)),
  update update: fn(model, msg) -> #(model, Effect(msg)),
  view view: fn(model) -> element.Element(msg),
  attribute_list attribute_list: List(#(String, fn(String) -> msg)),
  on_connect_msg on_connect_msg: msg,
) -> lustre.App(Nil, model, msg) {
  let styled_view = fn(model) {
    element.fragment([html.style([], "@import \"/app.css\";"), view(model)])
  }

  lustre.component(init: init, update: update, view: styled_view, options: [
    component.adopt_styles(False),
    component.open_shadow_root(True),
    component.on_connect(on_connect_msg),
    ..list.map(attribute_list, fn(tuple) {
      component.on_attribute_change(tuple.0, fn(value) { Ok(tuple.1(value)) })
    })
  ])
}
