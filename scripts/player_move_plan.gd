class_name PlayerMovePlan
extends RefCounted
## Value object shared by preview and authoritative player movement acceptance.
var full_route: NavigationService.Route=NavigationService.Route.new()
var route: NavigationService.Route=NavigationService.Route.new()
var limited: bool=false
func valid() -> bool:
 return route.valid()
