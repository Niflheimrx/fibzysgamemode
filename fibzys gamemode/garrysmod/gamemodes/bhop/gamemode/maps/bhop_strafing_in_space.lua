__HOOK[ "InitPostEntity" ] = function()
	for _,ent in pairs( ents.FindByClass( "func_rotating" ) ) do
		ent:Remove()
	end
end