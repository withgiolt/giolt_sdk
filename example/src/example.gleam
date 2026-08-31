import conversation.{Text}
import gleam/http/request
import gleam/http/response
import gleam/io
import lustre/element/html

pub fn main() -> Nil {
  io.println("Hello from example!")
}

pub const static_routes = [#([], index_page)]

pub fn index_page(_) {
  html.html([], [
    html.head([], [html.title([], "Hello world")]),
    html.body([], [html.text("Hello")]),
  ])
}

pub fn handler(_req: request.Request(String)) {
  response.new(200)
  |> response.set_header("content-type", "text/html; charset=utf-8")
  |> response.set_body(Text("<h1>Hello world</h1>"))
}
