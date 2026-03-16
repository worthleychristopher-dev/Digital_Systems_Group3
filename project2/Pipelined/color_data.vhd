package color_data is

	subtype color_channel_type is natural range 0 to 15;

	type rgb_color is
	record
		red:	color_channel_type;
		green:	color_channel_type;
		blue:	color_channel_type;
	end record rgb_color;

	constant color_black: rgb_color :=
		( red =>  0, green =>  0, blue =>  0 );
	constant color_red: rgb_color :=
		( red => 15, green =>  0, blue =>  0 );
	constant color_green: rgb_color :=
		( red =>  0, green => 15, blue =>  0 );
	constant color_blue: rgb_color :=
		( red =>  0, green =>  0, blue => 15 );
		
	subtype color_index_type is natural range 0 to 15;

	type color_table_type is array(color_index_type) of rgb_color;
	constant color_table_1: color_table_type := (
			15 => ( red => 0, green => 0, blue => 0 ),
			14 => ( red => 1, green => 15, blue => 15 ),
			13 => ( red => 2, green => 15, blue => 15 ),
			12 => ( red => 3, green => 15, blue => 15 ),
			11 => ( red => 4, green => 10, blue => 15 ),
			10 => ( red => 5, green => 10, blue => 15 ),
			9 => ( red => 6, green => 10, blue => 15 ),
			8 => ( red => 7, green => 10, blue => 15 ),
			7 => ( red => 8, green => 5, blue => 15 ),
			6 => ( red => 9, green => 5, blue => 15 ),
			5 => ( red => 10, green => 5, blue => 15 ),
			4 => ( red => 11, green => 5, blue => 15 ),
			3 => ( red => 12, green => 0, blue => 15 ),
			2 => ( red => 13, green => 0, blue => 15 ),
			1 => ( red => 14, green => 0, blue => 15 ),
			0 => ( red => 15, green => 0, blue => 15 )
		);

	constant color_table_2: color_table_type := (
			15 => ( blue => 0, red => 0, green => 0 ),
			14 => ( blue => 1, red => 15, green => 15 ),
			13 => ( blue => 2, red => 15, green => 15 ),
			12 => ( blue => 3, red => 15, green => 15 ),
			11 => ( blue => 4, red => 10, green => 15 ),
			10 => ( blue => 5, red => 10, green => 15 ),
			9 => ( blue => 6, red => 10, green => 15 ),
			8 => ( blue => 7, red => 10, green => 15 ),
			7 => ( blue => 8, red => 5, green => 15 ),
			6 => ( blue => 9, red => 5, green => 15 ),
			5 => ( blue => 10, red => 5, green => 15 ),
			4 => ( blue => 11, red => 5, green => 15 ),
			3 => ( blue => 12, red => 0, green => 15 ),
			2 => ( blue => 13, red => 0, green => 15 ),
			1 => ( blue => 14, red => 0, green => 15 ),
			0 => ( blue => 15, red => 0, green => 15 )
		);

	type color_palette_type is array(natural range<>) of color_table_type;
	constant color_palette_table: color_palette_type := (
			0 => color_table_1,
			1 => color_table_2,
			2 => (
				15 => ( green => 0, blue => 0, red => 0 ),
				14 => ( green => 1, blue => 15, red => 15 ),
				13 => ( green => 2, blue => 15, red => 15 ),
				12 => ( green => 3, blue => 15, red => 15 ),
				11 => ( green => 4, blue => 10, red => 15 ),
				10 => ( green => 5, blue => 10, red => 15 ),
				9 => ( green => 6, blue => 10, red => 15 ),
				8 => ( green => 7, blue => 10, red => 15 ),
				7 => ( green => 8, blue => 5, red => 15 ),
				6 => ( green => 9, blue => 5, red => 15 ),
				5 => ( green => 10, blue => 5, red => 15 ),
				4 => ( green => 11, blue => 5, red => 15 ),
				3 => ( green => 12, blue => 0, red => 15 ),
				2 => ( green => 13, blue => 0, red => 15 ),
				1 => ( green => 14, blue => 0, red => 15 ),
				0 => ( green => 15, blue => 0, red => 15 )
			)
		);

	subtype palette_index_type is natural range color_palette_table'range;

	function get_color (
			color_index: in color_index_type;
			color_table: in color_table_type
		) return rgb_color;

	function get_table (
			table_index: in palette_index_type
		) return color_table_type;

end package color_data;


package body color_data is

	function get_color (
			color_index: in color_index_type;
			color_table: in color_table_type
		) return rgb_color
	is
	begin
		return color_table(color_index);
	end function get_color;

	function get_table (
			table_index: in palette_index_type
		) return color_table_type
	is
	begin
		return color_palette_table(table_index);
	end function get_table;

end package body color_data; 
