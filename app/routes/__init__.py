"""HTTP routes, split by the tag they are grouped under in the OpenAPI schema.

`create_app` in app/main.py builds the application state and then includes
these routers. Each module owns one area of the API and reaches shared state
through the typed dependencies in app/dependencies.py.

Router include order matters where two paths could match the same request, so
routes stay in their original order within a module, and `create_app` includes
the modules in the order the routes were originally registered.
"""
