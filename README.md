# 🚨 DEPRECATION WARNING 🚨

This was a Docker image. I'm currently not using nor recommending the Docker image, it is no longer supported.

You are better off building a Docker image from scratch, see below how. 🤓

There are more details about the deprecation at the end.

## Build a Frontend Docker Image

### Previous steps

* Create your frontend Node.js based code (React, etc).

* Create a file `.dockerignore` (similar to `.gitignore`) and include in it:

```
node_modules
```

...to avoid copying your `node_modules` to Docker, making things unnecessarily slower.

* If you want to integrate testing as part of your frontend build inside your Docker image building process, install any dependencies you might need, for example Playwright, so that you can test it locally too and to have it in your development dependencies in your `package.json`:

```bash
npm init playwright@latest
```

### Dockerfile

* Create a file `Dockerfile` for building and name the stage `build-stage`:

```Dockerfile
# Stage 0, "build-stage", based on Node.js, to build and compile the frontend
FROM node:latest as build-stage

...

```

* Copy your `package.json` and possibly your `package-lock.json`:

```Dockerfile
...

WORKDIR /app

COPY package*.json /app/

...
```

...copy just the `package*.json` files to install all the dependencies once and let Docker use the cache for the next builds. By doing this before copying the whole app code, Docker will be able to use the cache and you won't have to wait for Docker to install with `npm install` every time you change the code.

* Install `npm` packages inside your `Dockerfile`:

```Dockerfile
...

RUN npm install

...
```

* Copy your source code to the Docker image:

```Dockerfile
...

COPY ./ /app/

...
```

* If you need to pass build arguments, create a default `ARG` to be used at build time:

```Dockerfile
...

ARG VITE_API_URL=${VITE_API_URL}

...
```

* If you have integrated testing, you can run your tests now:

```Dockerfile
...

RUN npm run test

...
```

...if your tests didn't pass, they will throw an error and your build will stop. So, you will never ship a "broken" frontend Docker image to production.

* Build your source frontend app as you normally would, with `npm`:

```Dockerfile
...

RUN npm run build

...
```

...after that, you would have a fresh build of your frontend app code inside a Docker image. But if you are serving frontend (static files) you could serve them with a high performance server as Nginx, and have a leaner Docker image without all the Node.js code.

* Create a new "stage" (just as if it was another Docker image in the same file) based on Nginx:

```Dockerfile
...

# Stage 1, based on Nginx, to have only the compiled app, ready for production with Nginx
FROM nginx:latest

...
```

* Now you will use the `build-stage` name created above in the previous "stage", copy the files generated there to the directory that Nginx uses:

```Dockerfile
...

COPY --from=build-stage /app/dist/ /usr/share/nginx/html

...
```

* Create a file `nginx.conf` with:

```Nginx
server {
  listen 80;

  location / {
    root /usr/share/nginx/html;
    index index.html index.htm;
    try_files $uri /index.html =404;
  }
}
```

* This configuration routes everything to your frontend app (to your `index.html`), so that you can use full URLs and they will always work, even if your users type them directly in the browser. Make your Docker image copy that configuration to Nginx's configurations directory:

```Dockerfile
...

COPY ./nginx.conf /etc/nginx/conf.d/default.conf

...
```

* Your final `Dockerfile` could look like:

```Dockerfile
# Stage 0, "build-stage", based on Node.js, to build and compile the frontend
FROM node:latest as build-stage

WORKDIR /app

COPY package*.json /app/

RUN npm install

COPY ./ /app/

ARG VITE_API_URL=${VITE_API_URL}

RUN npm run test

RUN npm run build


# Stage 1, based on Nginx, to have only the compiled app, ready for production with Nginx
FROM nginx:latest

COPY --from=build-stage /app/dist/ /usr/share/nginx/html/

COPY ./nginx.conf /etc/nginx/conf.d/default.conf
```

### Building the Docker image

* To build your shiny new image run:

```bash
docker build -t my-frontend-project:prod .
```

...If you had tests and added them above, they will be run. Your app will be compiled and you will end up with a lean high performance Nginx server with your fresh compiled app. Ready for production.

* If you need to pass build time arguments, for example if you have a "staging" environment, you can pass them like:

```bash
docker build -t my-frontend-project:stag --build-arg VITE_API_URL="https://staging.example.com" .
```

### Testing the Docker image

* Now, to test it, run:

```bash
docker run -p 80:80 my-frontend-project:prod
```

...if you are running Docker locally you can now go to `http://localhost` in your browser and see your frontend.

## Tips

* Develop locally, if you have a live reload server that runs with something like:

```bash
npm run start
```

...use it.

It's faster and simpler to develop locally. But once you think you got it, build your Docker image and try it. You will see how it looks in the full production environment.

* If you want to have tests using a (maybe headless) browser, run them locally first, as you normally would. Using the live normal browser. Make sure you have all the configurations right. Once you know it is running locally, you can add that to your `Dockerfile` and have "continuous integration" and "continuous building"... and if you want, add "continuous deployment". But first make it run locally, it's easier to debug only one step at a time.

* Have fun.

## Advanced Nginx configuration

You can include more Nginx configurations by copying them to `/etc/nginx/conf.d/`, beside the included Nginx configuration.

By default, this Nginx configuration routes everything to your frontend app (to your `index.html`). But if you want some specific routes to instead return, for example, an HTTP 404 "Not Found" error, you can include more nginx `.conf` files in the directory: `/etc/nginx/extra-conf.d/`.

For example, if you want your final Nginx to send 404 errors to `/api` and `/docs` you can create a file `nginx-backend-not-found.conf:

```Nginx
location /api {
    return 404;
}
location /docs {
    return 404;
}
```

And in your `Dockerfile` add a line:

```Dockerfile
COPY ./nginx-backend-not-found.conf /etc/nginx/extra-conf.d/nginx-backend-not-found.conf
```

### Details

These files will be included inside of an "[Nginx `server` directive](https://nginx.org/en/docs/http/ngx_http_core_module.html#server)".

So, you have to put contents that can be included there, like `location`.

---

This functionality was made to solve a very specific but common use case:

Let's say you have a load balancer on top of your frontend (and probably backend too), and it sends everything that goes to `/api/` to the backend, and `/docs` to an API documentation site (handled by the backend or other service), and the rest, `/`, to your frontend.

And your frontend has long-term caching for your main frontend app (as would be normal).

And then at some point, during development or because of a bug, your backend, that serves `/docs` is down.

You try to go there, but because it's down, your load balancer falls back to what handles `/`, your frontend.

So, you only see your same frontend instead of the `/docs`.

Then you check the logs in your backend, you fix it, and try to load `/docs` again.

But because the frontend had long-term caching, it still shows your same frontend at `/docs`, even though your backend is back online. Then you have to load it in an incognito window, or fiddle with the local cache of your frontend, etc.

By making Nginx simply respond with 404 errors when requested for `/docs`, you avoid that problem.

And because you have a load balancer on top, redirecting requests to `/docs` to the correct service, Nginx would never actually return that 404. Only in the case of a failure, or during development.

## Deprecated Image

This used to be a Docker image to simplify the process of creating a full Node.js environment for frontend development with multistage building.

It included all the dependencies for Puppeteer, so you could just `npm install puppeteer` and it should work.

It also included a default Nginx configuration for your frontend application, with the same content above, so in multi-stage Docker builds you could copy it to an Nginx "stage".

It is derived from this article I wrote:

> Angular in Docker with Nginx, supporting configurations / environments, built with multi-stage Docker builds and testing with Chrome Headless

 [in Medium](https://medium.com/@tiangolo/angular-in-docker-with-nginx-supporting-environments-built-with-multi-stage-docker-builds-bb9f1724e984), and [in GitHub](https://github.com/tiangolo/medium-posts/tree/master/angular-in-docker)

As copying the `nginx.conf` file to the `Dockerfile` is not that much work, and the dependencies for Puppeteer are probably no longer relevant as Playwright is in many cases a better option, it doesn't make sense to keep supporting this Docker image, and it doesn't make sense for you to use it.

You are better off following the instructions above. 🤓

## Release Notes

### Latest Changes

#### Fixes

* 🐛 Fix 403 errors when the url points to a directory without an index.html. PR [#5](https://github.com/tiangolo/node-frontend/pull/5) by [@jchorl](https://github.com/jchorl).

#### Internal

* ⬆ Bump tiangolo/issue-manager from 0.2.0 to 0.5.0. PR [#18](https://github.com/tiangolo/node-frontend/pull/18) by [@dependabot[bot]](https://github.com/apps/dependabot).
* 👷 Add dependabot. PR [#13](https://github.com/tiangolo/node-frontend/pull/13) by [@tiangolo](https://github.com/tiangolo).
* 🔧 Add funding. PR [#15](https://github.com/tiangolo/node-frontend/pull/15) by [@tiangolo](https://github.com/tiangolo).
* 👷 Add issue-manager GitHub Action. PR [#14](https://github.com/tiangolo/node-frontend/pull/14) by [@tiangolo](https://github.com/tiangolo).
* 👷 Add latest-changes GitHub Action. PR [#12](https://github.com/tiangolo/node-frontend/pull/12) by [@tiangolo](https://github.com/tiangolo).

### Initial Release

## License

This project is licensed under the terms of the MIT license.
