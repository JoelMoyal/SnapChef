-- Optional original sample catalog. Run as database administrator after migrations.
-- Stable IDs make re-running this seed harmless; existing samples are preserved.
insert into public.recipes(id,source,visibility,title,meal_type,cuisine,
  ingredients,steps,allergens,allergens_declared,dietary_tags,author_first_name)
values
('aaaaaaaa-0000-4000-8000-000000000001','catalog','published',
 'Tomato and chickpea skillet','Dinner','Mediterranean',
 '[{"name":"tomato","quantity":3,"unit":"piece"},{"name":"chickpeas","quantity":400,"unit":"g"},{"name":"olive oil","quantity":1,"unit":"tbsp"}]',
 '["Chop the tomatoes and drain the cooked chickpeas.","Warm the oil in a skillet, then add tomatoes and cook until softened.","Add chickpeas and simmer until hot throughout."]',
 '{}',true,array['Vegetarian','Vegan','Gluten-free','Dairy-free'],'SnapChef'),
('aaaaaaaa-0000-4000-8000-000000000002','catalog','published',
 'Spinach scrambled eggs','Breakfast','American',
 '[{"name":"eggs","quantity":2,"unit":"piece"},{"name":"spinach","quantity":40,"unit":"g"},{"name":"olive oil","quantity":1,"unit":"tsp"}]',
 '["Beat the eggs in a bowl.","Heat oil in a pan and wilt the spinach.","Add eggs and stir gently until fully set."]',
 array['Eggs'],true,array['Vegetarian','Gluten-free','Dairy-free'],'SnapChef'),
('aaaaaaaa-0000-4000-8000-000000000003','catalog','published',
 'Tomato rice bowl','Lunch','Mexican',
 '[{"name":"rice","quantity":150,"unit":"g"},{"name":"tomato","quantity":2,"unit":"piece"},{"name":"onion","quantity":1,"unit":"piece"}]',
 '["Cook the rice according to its package directions.","Chop tomatoes and onion, then simmer together in a covered pan until tender.","Stir the vegetables into the hot rice and serve."]',
 '{}',true,array['Vegetarian','Vegan','Gluten-free','Dairy-free'],'SnapChef')
on conflict (id) do nothing;
