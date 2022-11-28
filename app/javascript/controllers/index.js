// This file is auto-generated by ./bin/rails stimulus:manifest:update
// Run that command whenever you add a new controller or create them with
// ./bin/rails generate stimulus controllerName

import { application } from "./application"

import FilterController from "./filter_controller"
application.register("filter", FilterController)

import FormController from "./form_controller"
application.register("form", FormController)

import HelloController from "./hello_controller"
application.register("hello", HelloController)

import SearchController from "./search_controller"
application.register("search", SearchController)

import SidebarController from "./sidebar_controller"
application.register("sidebar", SidebarController)

import SortableController from "./sortable_controller"
application.register("sortable", SortableController)
