__HOOK[ "InitPostEntity" ] = function()
	for _,ent in pairs( ents.FindByClass( "func_illusionary" ) ) do
		ent:Remove()
	end
end