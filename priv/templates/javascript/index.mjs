import * as conversation from "../conversation/conversation.mjs";
import * as app from "../{project}/{project}.mjs";

export default {
  async fetch(request, _env, _ctx) {
    const req = conversation.to_gleam_request(request);
    const response = await app.handler(req);
    const res = conversation.to_js_response(response);

    return res;
  },
};
