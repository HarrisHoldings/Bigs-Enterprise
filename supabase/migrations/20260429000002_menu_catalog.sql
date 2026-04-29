-- ============================================================
-- LITTLE BIGS POS — STEP 2
-- Menu Catalog
-- ============================================================

-- ============================================================
-- MENU CATEGORIES
-- ============================================================

create table public.menu_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  slug text not null unique,
  description text,
  sort_order integer default 0,
  is_active boolean default true,
  created_at timestamptz default timezone('utc', now())
);

insert into public.menu_categories (name, slug, sort_order) values
  ('Pizzas',            'pizzas',           1),
  ('Signature Pizzas',  'signature-pizzas', 2),
  ('Detroit Style',     'detroit',          3),
  ('Chicago Deep Dish', 'chicago',          4),
  ('Calzone',           'calzone',          5),
  ('Wings',             'wings',            6),
  ('Wedgies',           'wedgies',          7),
  ('Subs',              'subs',             8),
  ('Pasta',             'pasta',            9),
  ('Salads',            'salads',           10),
  ('Sides',             'sides',            11),
  ('Desserts',          'desserts',         12),
  ('Drinks',            'drinks',           13),
  ('Sauces',            'sauces',           14),
  ('Extras',            'extras',           15);

-- ============================================================
-- PIZZA SIZES
-- ============================================================

create table public.pizza_sizes (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  slug text not null unique,
  diameter_inch numeric(4, 1),
  base_price decimal(10, 2) not null,
  sauce_oz numeric(4, 2) not null,
  cheese_oz numeric(4, 2) not null,
  topping_oz numeric(4, 2) not null,
  half_top_oz numeric(4, 2) not null,
  box_sku text,
  sort_order integer default 0,
  is_active boolean default true,
  created_at timestamptz default timezone('utc', now())
);

insert into public.pizza_sizes (
  name, slug, diameter_inch, base_price,
  sauce_oz, cheese_oz, topping_oz, half_top_oz,
  box_sku, sort_order
) values
  ('8 Inch Small',   '8-inch',  8.0,  5.50,  1.5, 2.0, 1.0, 0.5, '613138', 1),
  ('12 Inch Medium', '12-inch', 12.0, 8.50,  2.0, 4.0, 2.0, 1.5, '613140', 2),
  ('16 Inch Large',  '16-inch', 16.0, 14.75, 4.0, 8.0, 4.0, 2.0, '613142', 3),
  ('20 Inch XL',     '20-inch', 20.0, 16.75, 8.0, 10.0, 6.0, 3.0, '531572', 4);

-- ============================================================
-- CRUST TYPES
-- ============================================================

create table public.crust_types (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  slug text not null unique,
  sort_order integer default 0,
  is_active boolean default true,
  created_at timestamptz default timezone('utc', now())
);

insert into public.crust_types (name, slug, sort_order) values
  ('Raised',     'raised', 1),
  ('Flat',       'flat',   2),
  ('Thin',       'thin',   3);

-- ============================================================
-- TOPPINGS
-- ============================================================

create table public.toppings (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  slug text not null unique,
  category text not null check (category in (
                  'standard', 'premium', 'specialty', 'extra')),
  ingredient_id uuid references public.ingredients (id),
  is_cup_measured boolean default true,
  is_active boolean default true,
  sort_order integer default 0,
  created_at timestamptz default timezone('utc', now())
);

insert into public.toppings (name, slug, category, sort_order) values
  ('Pepperoni',      'pepperoni',       'standard',  1),
  ('Sausage',        'sausage',         'standard',  2),
  ('Ham',            'ham',             'standard',  3),
  ('Green Peppers',  'green-peppers',   'standard',  4),
  ('Sweet Peppers',  'sweet-peppers',   'standard',  5),
  ('Banana Peppers', 'banana-peppers',  'standard',  6),
  ('Black Olives',   'black-olives',    'standard',  7),
  ('Mushrooms',      'mushrooms',       'standard',  8),
  ('Onions',         'onions',          'standard',  9),
  ('Tomatoes',       'tomatoes',        'standard',  10),
  ('Lettuce',        'lettuce',         'standard',  11),
  ('Pineapple',      'pineapple',       'standard',  12),
  ('Pickles',        'pickles',         'standard',  13),
  ('Jalapenos',      'jalapenos',       'standard',  14),
  ('Steak',          'steak',           'premium',   15),
  ('Grilled Chicken','grilled-chicken', 'premium',   16),
  ('Crispy Chicken', 'crispy-chicken',  'premium',   17),
  ('Salami',         'salami',          'premium',   18),
  ('Bacon',          'bacon',           'premium',   19),
  ('Ground Beef',    'ground-beef',     'premium',   20),
  ('Ricotta',        'ricotta',         'specialty', 21),
  ('Spring Mix',     'spring-mix',      'specialty', 22),
  ('X-Mozzarella',   'x-mozzarella',    'extra',     23),
  ('X-Provolone',    'x-provolone',     'extra',     24),
  ('X-Sauce',        'x-sauce',         'extra',     25);

-- ============================================================
-- MENU ITEMS
-- ============================================================

create table public.menu_items (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  category_id uuid references public.menu_categories (id),
  description text,
  base_price decimal(10, 2),
  is_active boolean default true,
  sort_order integer default 0,
  created_at timestamptz default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create trigger menu_items_set_updated_at
  before update on public.menu_items
  for each row
  execute function public.set_updated_at();

insert into public.menu_items (name, slug, category_id, description, base_price, sort_order)
values
  ('Build Your Own Pizza 8 Inch',
   'byo-pizza-8',
   (select id from public.menu_categories where slug = 'pizzas'),
   'Build your own 8 inch pizza',
   5.50, 1),

  ('Build Your Own Pizza 12 Inch',
   'byo-pizza-12',
   (select id from public.menu_categories where slug = 'pizzas'),
   'Build your own 12 inch pizza',
   8.50, 2),

  ('Build Your Own Pizza 16 Inch',
   'byo-pizza-16',
   (select id from public.menu_categories where slug = 'pizzas'),
   'Build your own 16 inch pizza',
   14.75, 3),

  ('Build Your Own Pizza 20 Inch',
   'byo-pizza-20',
   (select id from public.menu_categories where slug = 'pizzas'),
   'Build your own 20 inch pizza',
   16.75, 4),

  ('Steak Pizza',
   'steak-pizza',
   (select id from public.menu_categories where slug = 'signature-pizzas'),
   'Mayo, Whole-Milk Mozzarella, Steak',
   14.00, 1),

  ('BBQ Chicken Pizza',
   'bbq-chicken-pizza',
   (select id from public.menu_categories where slug = 'signature-pizzas'),
   'Sweet Baby Rays BBQ, Mozzarella, Grilled Chicken',
   14.00, 2),

  ('BLT Pizza',
   'blt-pizza',
   (select id from public.menu_categories where slug = 'signature-pizzas'),
   'Mayo Base, Bacon, Lettuce, Tomato',
   14.00, 3),

  ('Buffalo Chicken Pizza',
   'buffalo-chicken-pizza',
   (select id from public.menu_categories where slug = 'signature-pizzas'),
   'Franks Red Hot, Chicken, Mozzarella',
   14.00, 4),

  ('Chicken Alfredo Pizza',
   'chicken-alfredo-pizza',
   (select id from public.menu_categories where slug = 'signature-pizzas'),
   'Mozzarella, Alfredo Sauce, Butter Garlic Crust, Tomatoes',
   14.00, 5),

  ('Chicken Bacon Ranch Pizza',
   'chicken-bacon-ranch-pizza',
   (select id from public.menu_categories where slug = 'signature-pizzas'),
   'Ranch Base, Mozzarella, Grilled Chicken, Bacon',
   14.00, 6),

  ('Deluxe Pizza',
   'deluxe-pizza',
   (select id from public.menu_categories where slug = 'signature-pizzas'),
   'Pepperoni, Mushrooms, Onions, Green Peppers, Sausage',
   14.00, 7),

  ('Hawaiian Pizza',
   'hawaiian-pizza',
   (select id from public.menu_categories where slug = 'signature-pizzas'),
   'Ham, Mozzarella, Pineapple, Red Sauce',
   14.00, 8),

  ('Meat Lovers Pizza',
   'meat-lovers-pizza',
   (select id from public.menu_categories where slug = 'signature-pizzas'),
   'Loaded with premium meats',
   14.00, 9),

  ('Pepperoni Lover Pizza',
   'pepperoni-lover-pizza',
   (select id from public.menu_categories where slug = 'signature-pizzas'),
   'Mozzarella, extra Pepperoni',
   14.00, 10),

  ('Spicy Italian Pizza',
   'spicy-italian-pizza',
   (select id from public.menu_categories where slug = 'signature-pizzas'),
   'Pepperoni, Parmesan, Red Sauce, Salami',
   14.00, 11),

  ('Super Deluxe Pizza',
   'super-deluxe-pizza',
   (select id from public.menu_categories where slug = 'signature-pizzas'),
   'Pepperoni, Mushrooms, Onions, Green Peppers, Sausage, Ham, Beef, Black Olives',
   14.00, 12),

  ('Taco Pizza',
   'taco-pizza',
   (select id from public.menu_categories where slug = 'signature-pizzas'),
   'Salsa, Ground Beef, Mozzarella, Tomato, Lettuce',
   14.00, 13),

  ('White Pizza',
   'white-pizza',
   (select id from public.menu_categories where slug = 'signature-pizzas'),
   'Ricotta Base, Mozzarella, Tomato, Spinach',
   14.00, 14),

  ('The Big Labogskies',
   'big-labogskies',
   (select id from public.menu_categories where slug = 'chicago'),
   'TONS of cheese, pepperoni, fresh sausage, topped with more cheese and red sauce',
   26.00, 1),

  ('Memphis Deep Dish',
   'memphis-deep-dish',
   (select id from public.menu_categories where slug = 'chicago'),
   'Double Dough, Grilled Chicken, Mozzarella, Sweet Baby Rays BBQ',
   26.00, 2),

  ('The Big Buff',
   'big-buff',
   (select id from public.menu_categories where slug = 'chicago'),
   '36 inches of dough, loaded whole-milk mozzarella. Ranch, Blue Cheese, or Plain',
   26.00, 3),

  ('The City',
   'the-city',
   (select id from public.menu_categories where slug = 'chicago'),
   'Double Dough, Signature Red Sauce, Mozzarella. Build your own.',
   22.00, 4),

  ('Calzone',
   'calzone',
   (select id from public.menu_categories where slug = 'calzone'),
   '2 toppings included',
   12.50, 1),

  ('6 Wings',         '6-wings',         (select id from public.menu_categories where slug = 'wings'), null, 7.50,  1),
  ('12 Wings',        '12-wings',        (select id from public.menu_categories where slug = 'wings'), null, 15.00, 2),
  ('24 Wings',        '24-wings',        (select id from public.menu_categories where slug = 'wings'), null, 30.00, 3),
  ('36 Wings',        '36-wings',        (select id from public.menu_categories where slug = 'wings'), null, 44.00, 4),
  ('50 Wings',        '50-wings',        (select id from public.menu_categories where slug = 'wings'), null, 59.00, 5),
  ('Boneless Wings',  'boneless-wings',  (select id from public.menu_categories where slug = 'wings'), '1 lb per order', 11.00, 6),

  ('12 Inch Wedgie',  '12-wedgie', (select id from public.menu_categories where slug = 'wedgies'), 'Meat, Mozzarella, Provolone, Lettuce, Tomato, Onion, Mayo', 11.50, 1),
  ('16 Inch Wedgie',  '16-wedgie', (select id from public.menu_categories where slug = 'wedgies'), 'Meat, Mozzarella, Provolone, Lettuce, Tomato, Onion, Mayo', 14.50, 2),

  ('BBQ Chicken Sub',     'bbq-chicken-sub',     (select id from public.menu_categories where slug = 'subs'), 'Grilled Chicken, Sweet Baby Rays BBQ, Provolone', 7.50,  1),
  ('BLT Sub',             'blt-sub',             (select id from public.menu_categories where slug = 'subs'), 'Bacon, Lettuce, Tomato', 7.50,  2),
  ('Buffalo Chicken Sub', 'buffalo-chicken-sub', (select id from public.menu_categories where slug = 'subs'), 'Grilled Chicken, Provolone, Franks Red Hot', 7.55,  3),
  ('Chicken Parm Sub',    'chicken-parm-sub',    (select id from public.menu_categories where slug = 'subs'), 'Chicken, Provolone, Signature Red Sauce', 7.55,  4),
  ('Ham and Cheese Sub',  'ham-cheese-sub',      (select id from public.menu_categories where slug = 'subs'), 'Ham, Provolone, Onions, Tomato, Mayo', 7.50,  5),
  ('Italian Sausage Sub', 'italian-sausage-sub', (select id from public.menu_categories where slug = 'subs'), 'Italian Sausage, Grilled Peppers and Onions, Marinara', 8.25,  6),
  ('Meatball Sub',        'meatball-sub',        (select id from public.menu_categories where slug = 'subs'), 'Provolone, Homemade Meatballs', 7.55,  7),
  ('Pepperoni Sub',       'pepperoni-sub',       (select id from public.menu_categories where slug = 'subs'), 'Lots of Pepperoni, Provolone', 7.50,  8),
  ('Spicy Italian Sub',   'spicy-italian-sub',   (select id from public.menu_categories where slug = 'subs'), 'Spicy Pepperoni, Provolone, Salami, Onion, Lettuce, Tomato, Mayo', 8.00,  9),
  ('Steak and Cheese Sub','steak-cheese-sub',    (select id from public.menu_categories where slug = 'subs'), 'Steak, Provolone, Mozzarella, Onion, Mayo', 7.50,  10),
  ('Tuna Sub',            'tuna-sub',            (select id from public.menu_categories where slug = 'subs'), null, 7.50,  11),
  ('Veggie Sub',          'veggie-sub',          (select id from public.menu_categories where slug = 'subs'), 'Ran through the entire garden', 7.00,  12),

  ('Spaghetti with Meatballs',        'spaghetti-meatballs',         (select id from public.menu_categories where slug = 'pasta'), null, 14.95, 1),
  ('Spaghetti with Meat Sauce',       'spaghetti-meat-sauce',        (select id from public.menu_categories where slug = 'pasta'), null, 14.95, 2),
  ('Spaghetti Plain',                 'spaghetti-plain',             (select id from public.menu_categories where slug = 'pasta'), null, 14.00, 3),
  ('Chicken Alfredo',                 'chicken-alfredo-pasta',       (select id from public.menu_categories where slug = 'pasta'), null, 14.95, 4),
  ('Honey Pepper Chicken Alfredo',    'honey-pepper-alfredo',        (select id from public.menu_categories where slug = 'pasta'), 'Crispy or Grilled. Regular or Bread Bowl', 17.00, 5),
  ('Baked Ziti',                      'baked-ziti',                  (select id from public.menu_categories where slug = 'pasta'), 'Penne, manicotti, meat sauce', 15.95, 6),
  ('Lasagna',                         'lasagna',                     (select id from public.menu_categories where slug = 'pasta'), 'Noodles, manicotti, red meat sauce, pepperoni', 15.95, 7),
  ('Eggplant Parmesan',               'eggplant-parmesan',           (select id from public.menu_categories where slug = 'pasta'), 'Breaded eggplant, Mozzarella', 15.50, 8),
  ('Veal Parmesan',                   'veal-parmesan',               (select id from public.menu_categories where slug = 'pasta'), 'Breaded Veal Cutlets, tomato sauce', 16.50, 9),
  ('Bread Bowl Spaghetti Meat Sauce', 'bread-bowl-spaghetti-meat',   (select id from public.menu_categories where slug = 'pasta'), 'Meat sauce in buttered garlic bread bowl', 14.95, 10),
  ('Bread Bowl Spaghetti Meatballs',  'bread-bowl-spaghetti-balls',  (select id from public.menu_categories where slug = 'pasta'), 'Meatballs in butter parmesan garlic bread bowl', 14.95, 11),
  ('Bread Bowl Chicken Alfredo',      'bread-bowl-chicken-alfredo',  (select id from public.menu_categories where slug = 'pasta'), 'Chicken Alfredo in signature bread bowl', 14.95, 12),

  ('Garden Salad',    'garden-salad',    (select id from public.menu_categories where slug = 'salads'), 'Fresh garden tossed, choice of veggies', 10.00, 1),
  ('Italian Salad',   'italian-salad',   (select id from public.menu_categories where slug = 'salads'), 'Ham, salami, pepperoni, provolone', 12.00, 2),
  ('Taco Salad',      'taco-salad',      (select id from public.menu_categories where slug = 'salads'), 'Seasoned beef, tortilla chips, 4oz salsa', 12.50, 3),
  ('Bread Bowl Salad','bread-bowl-salad',(select id from public.menu_categories where slug = 'salads'), 'Salad in bread bowl', 11.00, 4),
  ('Side Salad',      'side-salad',      (select id from public.menu_categories where slug = 'salads'), 'Lettuce, Tomato, Onion, Mozzarella', 3.75, 5),

  ('Chicken and Fries',    'chicken-and-fries',  (select id from public.menu_categories where slug = 'sides'), '5 tenders and 6oz crinkle fries', 8.50, 1),
  ('French Fries Small',   'fries-small',        (select id from public.menu_categories where slug = 'sides'), 'Hand cut Idaho potato or crinkle cut', 2.45, 2),
  ('French Fries Large',   'fries-large',        (select id from public.menu_categories where slug = 'sides'), 'Hand cut Idaho potato or crinkle cut', 3.80, 3),
  ('Onion Rings',          'onion-rings',        (select id from public.menu_categories where slug = 'sides'), null, 3.99, 4),
  ('Mozzarella Sticks',    'mozz-sticks',        (select id from public.menu_categories where slug = 'sides'), '6 count', 5.50, 5),
  ('Mushrooms',            'fried-mushrooms',    (select id from public.menu_categories where slug = 'sides'), '6 count', 5.50, 6),
  ('Jalapeno Poppers',     'jalapeno-poppers',   (select id from public.menu_categories where slug = 'sides'), null, 5.50, 7),
  ('Cheese Curds',         'cheese-curds',       (select id from public.menu_categories where slug = 'sides'), null, 6.50, 8),
  ('Ranch Cheese Curds',   'ranch-cheese-curds', (select id from public.menu_categories where slug = 'sides'), 'Ranch flavored', 6.50, 9),
  ('Hot Pepper Cubes',     'hot-pepper-cubes',   (select id from public.menu_categories where slug = 'sides'), null, 6.50, 10),
  ('Ravioli Bites',        'ravioli-bites',      (select id from public.menu_categories where slug = 'sides'), '8 pieces, ricotta, marinara side', 5.99, 11),
  ('Bread Sticks',         'bread-sticks',       (select id from public.menu_categories where slug = 'sides'), null, 5.50, 12),
  ('Loaded Fries',         'loaded-fries',       (select id from public.menu_categories where slug = 'sides'), 'Nacho Cheese, Bacon', 6.75, 13),
  ('Loaded Taco Nachos',   'loaded-nachos',      (select id from public.menu_categories where slug = 'sides'), 'Chips, Taco Meat, Cheddar, Onion, Tomato, Salsa, Sour Cream, Nacho Cheese', 11.50, 14),
  ('Nachos and Cheese',    'nachos-cheese',      (select id from public.menu_categories where slug = 'sides'), 'Chips with Nacho Cheese', 4.25, 15),
  ('Parmesan Bites',       'parmesan-bites',     (select id from public.menu_categories where slug = 'sides'), 'With red sauce', 6.55, 16),
  ('Cinnamon Bites',       'cinnamon-bites',     (select id from public.menu_categories where slug = 'sides'), 'With vanilla icing', 6.55, 17),
  ('Buffalo Chicken Roll', 'buffalo-roll',       (select id from public.menu_categories where slug = 'sides'), 'With 4oz sauce', 5.99, 18),
  ('Steak and Cheese Roll','steak-cheese-roll',    (select id from public.menu_categories where slug = 'sides'), 'With 4oz sauce', 5.99, 19),

  ('Apple Pizza',      'apple-pizza',      (select id from public.menu_categories where slug = 'desserts'), 'Apple, granola flakes, vanilla icing', 9.50, 1),
  ('Peach Pizza',      'peach-pizza',      (select id from public.menu_categories where slug = 'desserts'), 'Peaches, icing, granola flakes', 9.50, 2),
  ('Blueberry Pizza',  'blueberry-pizza',  (select id from public.menu_categories where slug = 'desserts'), 'Blueberry, icing, granola flakes', 9.50, 3),
  ('Cherry Pizza',     'cherry-pizza',     (select id from public.menu_categories where slug = 'desserts'), 'Cherry, granola, vanilla icing', 9.50, 4),

  ('Mild Sauce Cup',          'sauce-mild',         (select id from public.menu_categories where slug = 'sauces'), '4oz cup', 0.70, 1),
  ('Sweet Hot Sauce Cup',     'sauce-sweet-hot',    (select id from public.menu_categories where slug = 'sauces'), '4oz cup', 0.70, 2),
  ('Honey Hot Sauce Cup',     'sauce-honey-hot',    (select id from public.menu_categories where slug = 'sauces'), '4oz cup', 0.70, 3),
  ('BBQ Sauce Cup',           'sauce-bbq',          (select id from public.menu_categories where slug = 'sauces'), '4oz cup', 0.70, 4),
  ('Ranch Cup',               'sauce-ranch',        (select id from public.menu_categories where slug = 'sauces'), '4oz cup', 0.70, 5),
  ('Blue Cheese Cup',         'sauce-blue-cheese',  (select id from public.menu_categories where slug = 'sauces'), '4oz cup', 0.70, 6),
  ('Honey Mustard Cup',       'sauce-honey-mustard',(select id from public.menu_categories where slug = 'sauces'), '4oz cup', 0.70, 7),
  ('Marinara Cup',            'sauce-marinara',     (select id from public.menu_categories where slug = 'sauces'), '4oz cup', 0.70, 8),
  ('Alfredo Cup',             'sauce-alfredo',      (select id from public.menu_categories where slug = 'sauces'), '4oz cup', 0.70, 9),
  ('Honey Pepper Sauce Cup',  'sauce-honey-pepper', (select id from public.menu_categories where slug = 'sauces'), '4oz cup', 1.99, 10);
