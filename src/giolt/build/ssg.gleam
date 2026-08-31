import giolt/route
import gleam/http
import gleam/http/request
import gleam/io
import gleam/string
import lustre/element
import lustre/ssg
import simplifile

fn add_routes(
  config: ssg.Config(ssg.HasStaticRoutes, ssg.NoStaticDir, ssg.UseDirectRoutes),
  routes: List(#(List(String), fn(route.RouteContext) -> element.Element(Nil))),
) -> ssg.Config(ssg.HasStaticRoutes, ssg.NoStaticDir, ssg.UseDirectRoutes) {
  let assert Ok(dummy_req) = request.to("https://")
  let dummy_req =
    dummy_req
    |> request.set_method(http.Get)

  case routes {
    [] -> config
    [#(key, value), ..rest] ->
      add_routes(
        ssg.add_static_route(
          config,
          "/" <> string.join(key, "/"),
          value(route.RouteContext(
            req: dummy_req
            |> request.set_path("/" <> string.join(key, "/")),
          )),
        ),
        rest,
      )
  }
}

pub fn build(
  routes static_routes: List(
    #(List(String), fn(route.RouteContext) -> element.Element(Nil)),
  ),
  static_dir static_dir: String,
) {
  let build =
    ssg.new("./dist")
    |> ssg.add_static_route("/_", element.none())
    |> add_routes(static_routes)
    |> ssg.add_static_dir(static_dir)
    |> ssg.build

  case build {
    Ok(_) -> io.println("[GioltSDK] SSG succeeded!")
    Error(e) -> {
      echo e
      panic as "[GioltSDK] SSG failed!"
    }
  }

  let _ = simplifile.delete("./dist/_.html")

  Nil
}
