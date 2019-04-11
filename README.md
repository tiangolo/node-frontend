## Supported tags and respective `Dockerfile` links

* [`10`, `latest` _(Dockerfile)_](https://github.com/tiangolo/node-frontend/blob/master/Dockerfile)

# Node.js frontend development with Chrome Headless tests

This Docker image simplifies the process of creating a full Node.js environment for frontend development with multistage building.

It includes all the dependencies for Puppeteer, so you can just `npm install puppeteer` and it should work.

It also includes a default Nginx configuration for your frontend application, so in multi-stage Docker builds you can just copy it to an Ngnix "stage" and have an always freshly compiled production ready frontend Docker image for deployment.

It is derivated from this article I wrote:

> Angular in Docker with Nginx, supporting configurations / environments, built with multi-stage Docker builds and testing with Chrome Headless

 [in Medium](https://medium.com/@tiangolo/angular-in-docker-with-nginx-supporting-environments-built-with-multi-stage-docker-builds-bb9f1724e984), and [in GitHub](https://github.com/tiangolo/medium-posts/tree/master/angular-in-docker)

 ## How to use

### Previous steps

* Create your frontend Node.js based code (Angular, React, Vue.js).

* Create a file `.dockerignore` (similar to `.gitignore`) and include in it:

```
node_modules
```

...to avoid copying your `node_modules` to Docker, making things unnecessarily slower.

* If you want to integrate testing as part of your frontend build inside your Docker image building process (using Chrome Headless via Puppeteer), install Puppeteer locally, so that you can test it locally too and to have it in your development dependencies in your `package.json`:

```bash
npm install --save-dev puppeteer
```

### Dockerfile

* Create a file `Dockerfile` based on this image and name the stage `build-stage`, for building:

```Dockerfile
# Stage 0, "build-stage", based on Node.js, to build and compile the frontend
FROM tiangolo/node-frontend:10 as build-stage

...

```

* Copy your `package.json` and possibly your `package-lock.json`:

```Dockerfile
...

WORKDIR /app

COPY package*.json /app/

...
```

...just the `package*.json` files to install all the dependencies once and let Docker use the cache for the next builds. Instead of installing everything after every change in your source code.

* Install `npm` packages inside your `Dockerfile`:

```Dockerfile
...

RUN npm install

...
```

* Copy your source code, it can be TypeScript files, `.vue` or React with JSX, it will be compiled inside Docker:


```Dockerfile
...

COPY ./ /app/

...
```

* If you have integrated testing with Chrome Headless using Puppeteer, this image comes with all the dependencies for Puppeteer, so, after installing your dependencies (including `puppeteer` itself), you can just run it. E.g.:

```Dockerfile
...

RUN npm run test -- --browsers ChromeHeadlessNoSandbox --watch=false

...
```

...if your tests didn't pass, they will throw an error and your build will stop. So, you will never ship a "broken" frontend Docker image to production.

* If you need to pass buildtime arguments, for example in Angular, for `--configuration`s, create a default `ARG` to be used at build time:

```Dockerfile
...

ARG configuration=production

...
```

* Build your source frontend app as you normally would, with `npm`:

```Dockerfile
...

RUN npm run build

...
```

* If you need to pass build time arguments (for example in Angular), modify the previous instruction using the previously declared `ARG`, e.g.:

```Dockerfile
...

RUN npm run build -- --output-path=./dist/out --configuration $configuration

...
```

...after that, you would have a fresh build of your frontend app code inside a Docker container. But if you are serving frontend (static files) you could serve them with a high performance server as Nginx, and have a leaner Docker image without all the Node.js code.

* Create a new "stage" (just as if it was another Docker image in the same file) based on Nginx:

```Dockerfile
...

# Stage 1, based on Nginx, to have only the compiled app, ready for production with Nginx
FROM nginx:1.15

...
```

* Now you will use the `build-stage` name created above in the previous "stage", copy the files generated there to the directory that Nginx uses:

```Dockerfile
...

COPY --from=build-stage /app/dist/out/ /usr/share/nginx/html

...
```

... make sure you change `/app/dist/out/` to the directory inside `/app/` that contains your compiled frontend code.

* This image also contains a default Nginx configuration so that you don't have to provide one. By default it routes everything to your frontend app (to your `index.html`), so that you can use "HTML5" full URLs and they will always work, even if your users type them directly in the browser. Make your Docker image copy that default configuration from the previous stage to Nginx's configurations directory:

```Dockerfile
...

COPY --from=build-stage /nginx.conf /etc/nginx/conf.d/default.conf

...
```

* Your final `Dockerfile` could look like:

```Dockerfile
# Stage 0, "build-stage", based on Node.js, to build and compile the frontend
FROM tiangolo/node-frontend:10 as build-stage

WORKDIR /app

COPY package*.json /app/

RUN npm install

COPY ./ /app/

RUN npm run test -- --browsers ChromeHeadlessNoSandbox --watch=false

ARG configuration=production

RUN npm run build -- --output-path=./dist/out --configuration $configuration


# Stage 1, based on Nginx, to have only the compiled app, ready for production with Nginx
FROM nginx:1.15

COPY --from=build-stage /app/dist/out/ /usr/share/nginx/html

COPY --from=build-stage /nginx.conf /etc/nginx/conf.d/default.conf
```

### Building the Docker image

* To build your shiny new image run:

```bash
docker build -t my-frontend-project:prod .
```

...If you had tests and added above, they will be run. Your app will be compiled and you will end up with a lean high performance Nginx server with your fresh compiled app. Ready for production.

* If you need to pass build time arguments (like for Angular `--configuration`s), for example if you have a "staging" environment, you can pass them like:

```bash
docker build -t my-frontend-project:stag --build-arg configuration="staging" .
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

* If you want to have Chrome Headless tests, run them locally first, as you normally would (Karma, Jasmine, Jest, etc). Using the live normal browser. Make sure you have all the configurations right. Then install Puppeteer locally and make sure it runs locally (with local Headless Chrome). Once you know it is running locally, you can add that to your `Dockerfile` and have "continuous integration" and "continuous building"... and if you want add "continuous deployment". But first make it run locally, it's easier to debug only one step at a time.

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

## License

This project is licensed under the terms of the MIT license.
