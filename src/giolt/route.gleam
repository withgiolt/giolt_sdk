import gleam/http/request

pub type RouteContext {
  RouteContext(req: request.Request(String))
}
