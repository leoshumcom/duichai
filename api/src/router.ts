/**
 * URL 路由匹配
 */

type RouteHandler = (request: Request, params: Record<string, string>) => Response | Promise<Response>;

interface Route {
  method: string;
  pattern: RegExp;
  paramNames: string[];
  handler: RouteHandler;
}

export class Router {
  private routes: Route[] = [];

  add(method: string, path: string, handler: RouteHandler): void {
    const paramNames: string[] = [];
    const regexStr = path
      .replace(/:([^/]+)/g, (_, name) => {
        paramNames.push(name);
        return '([^/]+)';
      })
      .replace(/\*\*/g, '.*')
      .replace(/\*/g, '[^/]*');

    this.routes.push({
      method,
      pattern: new RegExp(`^${regexStr}$`),
      paramNames,
      handler,
    });
  }

  async handle(request: Request): Promise<Response> {
    const url = new URL(request.url);
    const path = url.pathname;
    const method = request.method;

    for (const route of this.routes) {
      if (route.method !== method && route.method !== 'ALL') continue;

      const match = path.match(route.pattern);
      if (match) {
        const params: Record<string, string> = {};
        route.paramNames.forEach((name, i) => {
          params[name] = decodeURIComponent(match[i + 1]);
        });
        return await route.handler(request, params);
      }
    }

    return new Response(JSON.stringify({ error: 'Not Found', code: 404 }), {
      status: 404,
      headers: { 'Content-Type': 'application/json' },
    });
  }
}
