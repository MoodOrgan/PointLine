/////////////////////////////////////////////////////////// •- /////////////////////////////////////////////////////////
// 
// timm.mason@gmail.com
// 201805XX – 20190513

// TODO
// change GROWTH to use proximity to canvas edges
// keep array of distance_map entries to delete in die()
// NAV:when going toward large city, the corner area upsets navigation
// add REC mode
// rewrite City.display() with gradient

import java.util.Map;
import java.util.Set;

int DEBUG = 1;
boolean HIRES = false;
boolean REC   = false;

int canvas_w = 900;
int canvas_h = 700;


PImage path_map;
HashMap<Integer, Boolean> active_pixels;
int max_active_pixels = canvas_w * canvas_h / 16;
int active_pixel;
Set<Integer> active_pixels_keyset;
Integer active_pixels_array[];
int num_active_pixels;
int pixel_index;

boolean f, ff, fl, fll, fr, frr, ffl, ffr, l, ll, r, rr, bl, bll, br, brr;
int x_min = canvas_w, x_max = 0, y_min = canvas_h, y_max = 0;
City city_N, city_E, city_S, city_W;

color red   = color(255, 0, 0);
color white = color(255, 255, 255);
color black = color(0, 0, 0);
color color_inc = color(1, 1, 1);
color grey = color(128, 128, 128);

int step_counter = 0;
int fade_turn_period = 8;

int time_step = 12; // milliseconds
int now;
int last_step;

int init_cities  = 32;
int made_cities = 0;    // used by initialization procedure
int max_cities = 512;   // not a real maximum, but the init size of the ArrayList cities
int max_city_population = 75;    // when exceeded, EXPLODE
ArrayList<City> cities;
City cities_array[];
HashMap<IndexPair, Float> distance_map;

int init_population = 512;
int max_populace = 4096;
ArrayList<Personoid> populace;
Personoid populace_array[];

float trapped_personoid_dies_odds = 0.88;


void settings() {
    size(canvas_w, canvas_h);
}

void setup() {
  path_map = createImage(canvas_w, canvas_h, RGB);
  active_pixels = new HashMap<Integer, Boolean>(max_active_pixels);
  active_pixels_array = new Integer[max_active_pixels];
  distance_map = new HashMap<IndexPair, Float>(max_cities * max_cities);
  path_map.loadPixels();
  
  for (int i=0; i<canvas_h; i++) {
    for (int j=0; j<canvas_w; j++) {
      if ((i==0) || (i==canvas_h-1) || (j==0) || (j==canvas_w-1)) { // black border
        path_map.pixels[i*canvas_w + j] = black;
      } else {
        path_map.pixels[i*canvas_w + j] = white;
      }
    }
  }
  
  cities = new ArrayList<City>(init_cities);
  cities_array = new City[max_cities];
  for (int i=0; i<init_cities; i++) { // random arrangement
    new City();
    made_cities++;
  } 
  
  populace = new ArrayList<Personoid>(init_population);
  populace_array = new Personoid[max_populace];
  for (int i=0; i<init_population; i++) new Personoid();
  
  now = millis();
  last_step = now;
  
  noStroke();
}

void growth_select() {
  switch (int(random(6))) {
    case 0:
      if (city_N == null) {
        for (City c : cities)
          if (c.y < y_min) { y_min = c.y; city_N = c; }
      }
      city_N.growth(1);
      break;
    case 1:
      if (city_E == null) {
        for (City c : cities)
          if (c.x > x_max) { x_max = c.x; city_E = c; }
      }
      city_E.growth(1);
      break;
    case 2:
      if (city_S == null) {
        for (City c : cities)
          if (c.y > y_max) { y_max = c.y; city_S = c; }
      }
      city_S.growth(1);
      break;
    case 3:
      if (city_W == null) {
        for (City c : cities)
          if (c.x < x_min) { x_min = c.x; city_W = c; }
      }
      city_W.growth(1);
      break;
  }
}

void draw() {
  now = millis();

  if (now - time_step > last_step) {
    step_counter++;
    
    cities_array = cities.toArray(cities_array);
    for (int i = cities.size() - 1;   i >= 0; i--) {
      if (cities_array[i] != null) cities_array[i].update();
    }
        
    populace_array = populace.toArray(populace_array);
    for (int i = populace.size() - 1; i >= 0; i--) {
      if (populace_array[i] != null) populace_array[i].update();
    }
    
    if (step_counter % fade_turn_period == 0) {    // FADE TURN
      if (step_counter % (fade_turn_period * 32) == 0) {
        growth_select();

        if (DEBUG > 0) {
          println((step_counter / fade_turn_period / 32) + ":\t" + populace.size() + " Personoids\t" + cities.size() + " Cities");
          println("\t\t" + distance_map.size() + " entries in distance_map"); // DEBUG
        }
      }
        
      if (cities.size() >= 3) {
        City a, b;
        
        a = cities.get(int(random(cities.size())));
        do {
          b = cities.get(int(random(cities.size())));
        } while (a == b);
        
        if ((random(1.0) < 0.09) && (a.residents.size() < 2) && (b.residents.size() < 2) 
            && (now - a.creation_time > 1024) && (now - b.creation_time > 1024)) { // SEEK
          if (DEBUG > 1) println("SEEK: a = (" + a.x + ", " + a.y + "),\tb = (" + b.x + ", " + b.y + ")");
          Personoid p;
          City new_destination;

          do {
            new_destination = cities.get(int(random(cities.size())));
          } while ((new_destination == a) || (new_destination == b));

          if (a.residents.size() > 0) {
            for (int i=a.residents.size()-1; i>=0; i--) {
              p = a.residents.get(i);
              a.remove_resident(p);
              p.destination = new_destination;
            }
          } else { // BIRTH
            p = new Personoid(a.x, a.y);
            p.destination = new_destination;
            p.update();
  
            if (DEBUG > 1) println("\ta: new Personoid(" + populace.size() + ")");
          }
              
          if (b.residents.size() > 0) {
            for (int i=b.residents.size()-1; i>=0; i--) {
              p = b.residents.get(i);
              b.remove_resident(p);
              p.destination = new_destination;
            }
          } else { // BIRTH
            p = new Personoid(b.x, b.y);
            p.destination = new_destination;
            p.update();
            
            if (DEBUG > 1) println("\tb: new Personoid(" + populace.size() + ")");
          }
        }
      }

      active_pixels_keyset = active_pixels.keySet();
      num_active_pixels = active_pixels_keyset.size();
      active_pixels_array = active_pixels_keyset.toArray(active_pixels_array);
      for (int i=0; i<num_active_pixels; i++) {      // FADE PATHS
        active_pixel = active_pixels_array[i];
        path_map.pixels[active_pixel] = color(min((path_map.pixels[active_pixel] >> 16 & 0xFF) + 1.0, 255.0));
        if (path_map.pixels[active_pixel] == white) {
          active_pixels.remove(active_pixel);
        }
      }
    }

    path_map.updatePixels();
    image(path_map, 0, 0);
    
    for (City c : cities)  c.display();
    
    if (HIRES) { filter(BLUR); }

    last_step = now;
  }
}

 class IndexPair {  // store a pair of pixel indices - this is a key for distance_map
  int a, b;
  
  IndexPair(int a_new, int b_new) {
    if (a_new < b_new) {
      a = a_new;
      b = b_new;
    } else {
      a = b_new;
      b = a_new;
    }
  }
  
  public boolean equals(Object obj) {
    if (obj == this) return true;
    if (!(obj instanceof IndexPair)) return false;
    IndexPair new_ip = (IndexPair) obj;
    return (new_ip.a == this.a) && (new_ip.b == this.b);
  }
  
  public int hashCode() {
    int result=17;
    result=31*result+a;
    result=31*result+b;
    return result;
  }
}

class City {
  int x, y;
  int pixel_index;
  float r, target_r;
  int r_int;
  int creation_time;
  int last_growth = step_counter;
  int last_departure;
  int last_city_checked;
  ArrayList<Personoid> residents;
  
  City() {
    boolean coordinates_taken;
    
    residents = new ArrayList<Personoid>();

    if (DEBUG > 1) print("city " + made_cities + "\t");
    do {
      x = 50 + int(random(canvas_w - 100));
      y = 50 + int(random(canvas_h - 100));
      coordinates_taken = false;
      
      for (int i=0; i<made_cities; i++) {
        if ((abs(cities.get(i).x - x) <= 25) && (abs(cities.get(i).y - y) <= 25)) {
          coordinates_taken = true;
          break;
        }
      }
      if (DEBUG > 1) println();
    } while(coordinates_taken);
    
    calculate_pixel_index();
    r = 1.0;
    calculate_r();
    creation_time = now;
    last_departure = 0;
    last_city_checked = 0;
    cities.add(this);
    update_cityNESW();
  }
  
  City(int x_in, int y_in) {
    residents = new ArrayList<Personoid>();
    x = x_in;
    y = y_in;
    calculate_pixel_index();
    r = 1.0;
    calculate_r();
    creation_time = now;
    last_departure = 0;
    last_city_checked = 0;
    cities.add(this);
    update_cityNESW();
  }
  
  void update_cityNESW() {
    if (x > x_max) { x_max = x; city_E = this; }
    if (x < x_min) { x_min = x; city_W = this; }
    if (y > y_max) { y_max = y; city_S = this; }
    if (y < y_min) { y_min = y; city_N = this; }
  }
  
  void calculate_r() {
    target_r = float(residents.size());
    r += (target_r - r) / 100.0;
    r_int = int(r);
  }
  
  private int calculate_pixel_index() {
    pixel_index = y * canvas_w + x;
    return pixel_index;
  }
  
  int get_pixel_index() {
    return pixel_index;
  }
  
  float get_distance_to_city(City c) {
    float d;
    IndexPair ip = new IndexPair(this.get_pixel_index(), c.get_pixel_index());
    
    if (distance_map.containsKey(ip)) {
      return distance_map.get(ip);
    } else {
      d = sqrt(pow(abs(c.x - x), 2) + pow(abs(c.y - y), 2.0));
      distance_map.put(ip, d);
      return d;
    }
  }
  
  void add_resident(Personoid p) {
    if (!residents.contains(p)) {
      residents.add(p);
      p.enter_city(this);
      calculate_r();
    }
  }
  
  void remove_resident(Personoid p) {
    if (residents.contains(p)) {
      residents.remove(p);
      last_departure = now;
      cities.remove(this); cities.add(this);     // move self to tail of cities[]
      p.exit_city();
    }
  }
  
  void growth(int growth_index) {
    Personoid p;
    for (int i = 0; i < growth_index; i++) {
      p = new Personoid(this);
    }
    last_growth = step_counter;
  }
  
  void die() {
    if (DEBUG > 1) println("\tDEAD CITY (" + cities.size() + ")");
    for (int i = residents.size() - 1; i >= 0; i++ ) residents.get(i).die();
    cities.remove(this);
    
    if (city_N == this) { city_N = null; y_min = canvas_h; }
    if (city_E == this) { city_E = null; x_max = 0; }
    if (city_S == this) { city_S = null; y_max = 0; }
    if (city_W == this) { city_W = null; x_min = canvas_w; }
  }
  
  void update() {
    City c;

    calculate_r();
    if (r <= 0.01) {
      if (DEBUG > 1) println("DEAD CITY wither");
      die();
    }
    
    if (r_int > max_city_population) {
      Personoid p;
      boolean xy_found = false;
      int trial_x=0, trial_y=0;
      if (DEBUG > 1) println("EXPLODE");
      for (int j = residents.size() - 1; j >= 0; j--) {
        for (int i=0; i<4; i++) {
          xy_found = false;
          trial_x = x + int(random(4.0*r)-r+1.0);
          trial_y = y + int(random(4.0*r)-r+1.0);
          if ((trial_x > canvas_w-3) || (trial_x < 3) || (trial_y > canvas_h - 3) || (trial_y < 3)) continue;
          if ((path_map.pixels[trial_y*canvas_w + trial_x] == white)
              && (sqrt(pow(abs(trial_x - x), 2) + pow(abs(trial_y - y), 2)) <= 2.0*r)) {
              xy_found = true;
              break;
          }
        }

        p = residents.get(j);
        remove_resident(p);

        if (xy_found) {
          p.set_xy(trial_x, trial_y);
//          p.x = trial_x;
//          p.y = trial_y;
          p.choose_new_destination(min(canvas_w, canvas_h));
        } else {
          if (DEBUG > 1) println("\tDEATH explosion");
          p.die();
        }
      }
      
      if (DEBUG > 1) println("\tDEAD CITY explosion");
      die();
    }

    for (int j=0; j<r_int/2; j++) { // check a few cities to see if we surround them.
      last_city_checked++;  if (last_city_checked >= cities.size()) last_city_checked = 0;

      c = cities.get(last_city_checked);
      if (this == c) continue;
      if ((abs(c.x - x) > r_int) || (abs(c.y - y) > r_int)) continue;
  
      if ((x + r_int > c.x + c.r_int) && (x - r_int < c.x - c.r_int) && (y + r_int > c.y + c.r_int) && (y - r_int < c.y - c.r_int)) { //<>//
        if (residents.size() < c.residents.size() * 3) {  // EXCHANGE
          Personoid p;
          if (DEBUG > 1) println("EXCHANGE " + this + " \tsize = " + c.residents.size());
          for (int i=residents.size()-1; i>=0; i--) {
            if (random(1.0) > 0.5) { // if we surround city c, they randomly take half our residents
              p = residents.get(i);
              this.remove_resident(p);
              c.add_resident(p);
            }
          } 
        } else {      // ABSORB
          if (DEBUG > 1) println("ABSORB (" + c.x + ", " + c.y + ") \tsize = " + c.residents.size());
          for (int i=c.residents.size()-1; i>=0; i--) {
            Personoid p = c.residents.get(i);
            c.remove_resident(p);
            this.add_resident(p);
          }
          if (DEBUG > 1) println("\tDEAD CITY absorb");
          c.die();
        }
      }
    }
  }
  
  void display() {
    float grey = min(64.0-6.0*r + (now - last_departure)/96.0, 200);
    float growth_interval = step_counter - last_growth;

    if (r <= 1.0) {
      fill(color(red));
    } else if (growth_interval < 255.0) {
      fill(color(grey, max(202 - growth_interval, grey), grey, 128));
    } else {
      fill(color(grey, 128)); 
    }
    ellipse(x, y, 4.0*r, 4.0*r);
    fill(color(255, 212));
    ellipse(x, y, 2.0*r, 2.0*r);
  }
}

class Personoid {
  int x, y;
  int pixel_index;
  int momentum; // NESW
  boolean in_transit = false;
  City city;
  City destination;
  int time_in_city = 0;
  int time_in_transit = 0;
  int time_of_last_turn = 0;
  
  Personoid(City c) { // Personoid in City c
    city = c;
    city.add_resident(this);
    x = city.x;
    y = city.y;
    calculate_pixel_index();
    choose_new_destination(min(canvas_w, canvas_h));
    momentum = int(random(4));
    in_transit = false;
    populace.add(this);
  }
  
  Personoid() { // Personoid in random City
    city = cities.get(int(random(cities.size())));
    city.add_resident(this);
    x = city.x;
    y = city.y;
    calculate_pixel_index();
    choose_new_destination(min(canvas_w, canvas_h));
    momentum = int(random(4));
    in_transit = false;
    populace.add(this);
  }
  
  Personoid(int new_x, int new_y) { // Personoid not in city
    city = null;
    x = new_x;
    y = new_y;
    calculate_pixel_index();
    choose_new_destination(min(canvas_w, canvas_h));
    momentum = int(random(4));
    in_transit = true;
    populace.add(this);
  }
  
  void calculate_pixel_index() {
    pixel_index = y * canvas_w + x;
  }
  
  int get_pixel_index() {
    return pixel_index;
  }
  
  void die() {
    if (city != null) exit_city();
    populace.remove(this);
    if (DEBUG > 1) println("\tDEAD PERSONOID (" + populace.size() + ")");
  }
  
  void print_info() {
    println("\tPersonoid #{this.object_id}:");
    print("\t\t(" + x + ", " + y + ") --> ");
    if (destination == null) {
      println("null");
    } else {
      println("(#{destination.x}, #{destination.y})");
    }
    println("\t\tmomentum = " + momentum);
    if (city == null) {
      println("\t\tcity = null");
    } else {
      println("\t\tcity = " + city + "\t(" + city.x + ", " + city.y + ")");
    }
    println("\t\tin_transit = " + in_transit + "\ttime_in_transit = " + time_in_transit
            + "\ttime_in_city = " + time_in_city + "\ttime_of_last_turn = " + time_of_last_turn);
    
  }
  
  void set_xy(int new_x, int new_y) {
    x = new_x;
    y = new_y;
    calculate_pixel_index();
  }
  
  void enter_city(City c) {
    city = c;
    in_transit = false;
    time_in_city = 0;
    time_in_transit = 0;
    set_xy(x, y);
    c.add_resident(this);
  }
  
  void exit_city() {
    City c = city;
    city = null;
    in_transit = true;
    time_in_city = 0;
    time_in_transit = 0;
    c.remove_resident(this);
  }

  City choose_new_destination(int choice_radius) {
    int min = populace.size();
    for (City c : cities) {
      if ((city != null) && ((abs(c.x - city.x) > choice_radius) || (abs(c.y - city.y) > choice_radius))) continue;
      if (c.residents.size() < min) {
        min = c.residents.size();
        destination = c;
        if (min <= 1) return c;
        if (random(1.0) > 0.95) return c;
      }
    }
    return null;
  }
  
  void update() {
    if (!in_transit) { // Personoid occupies a city
      time_in_city++;
      if ((time_in_city > 64) && (now - city.last_departure > 512)) {//city.last_departure < (last_step - time_step*1024))) {
        choose_new_destination(min(canvas_w, canvas_h) / 2);
//        if (random(12000) < (city.residents.size() - destination.r_int + 1)) { // DEPART
        if (random(12000) < (city.r - destination.r)) { // DEPART
          int gate;

          in_transit = true;
/*          do {
            gate = int(random(4));
          } while (((gate == 0) && (destination.y > y)) || 
                   ((gate == 1) && (destination.x < x)) ||
                   ((gate == 2) && (destination.y < y)) ||
                   ((gate == 3) && (destination.x > x)));  */
          
          gate = int(random(4));
          for (int i = 0; i < 4; i++) {
            switch ((gate + i) % 4) {
            case 0:   // N
              if (destination.y > y) continue;
              if (city.y - city.r_int < 3) continue;
              set_xy(city.x, max(city.y - city.r_int, 2));
              break;
              
            case 1:   // E
              if (destination.x < x) continue;
              if (city.x + city.r_int > canvas_w - 3) continue;
              set_xy(min(city.x + city.r_int, canvas_w-2), city.y);
              break;
              
            case 2:   // S
              if (destination.y < y) continue;
              if (city.y + city.r_int > canvas_h - 3) continue;
              set_xy(city.x, min(city.y + city.r_int, canvas_h-2));
              break;

            case 3:   // W
              if (destination.x > x) continue;
              if (city.x - city.r_int < 3) continue;
              set_xy(max(city.x - city.r_int, 2), city.y);
              break;
            }
            if (path_map.pixels[get_pixel_index()] != white) continue;
          }
                   
          do {
            momentum = int(random(4));
          } while ((gate + 2) % 4 == momentum);
          
          switch (momentum) {
          case 0:
            f   = path_map.pixels[(y-1)*canvas_w +   x] == white;
            fl  = path_map.pixels[(y-1)*canvas_w + x-1] == white;
            fr  = path_map.pixels[(y-1)*canvas_w + x+1] == white;
            ff  = path_map.pixels[(y-2)*canvas_w +   x] == white;
            ffl = path_map.pixels[(y-2)*canvas_w + x-1] == white;
            ffr = path_map.pixels[(y-2)*canvas_w + x+1] == white;
            break;
          case 1:
            f   = path_map.pixels[(y)*canvas_w   + x+1] == white;
            fl  = path_map.pixels[(y-1)*canvas_w + x+1] == white;
            fr  = path_map.pixels[(y+1)*canvas_w + x+1] == white;
            ff  = path_map.pixels[(y)*canvas_w   + x+2] == white;
            ffl = path_map.pixels[(y-1)*canvas_w + x+2] == white;
            ffr = path_map.pixels[(y+1)*canvas_w + x+2] == white;
            break;
          case 2:
            f   = path_map.pixels[(y+1)*canvas_w +   x] == white;
            fl  = path_map.pixels[(y+1)*canvas_w + x+1] == white;
            fr  = path_map.pixels[(y+1)*canvas_w + x-1] == white;
            ff  = path_map.pixels[(y+2)*canvas_w +   x] == white;
            ffl = path_map.pixels[(y+2)*canvas_w + x+1] == white;
            ffr = path_map.pixels[(y+2)*canvas_w + x-1] == white;
            break;
          case 3:
            f   = path_map.pixels[(y)*canvas_w   + x-1] == white;
            fl  = path_map.pixels[(y+1)*canvas_w + x-1] == white;
            fr  = path_map.pixels[(y-1)*canvas_w + x-1] == white;
            ff  = path_map.pixels[(y)*canvas_w   + x-2] == white;
            ffl = path_map.pixels[(y+1)*canvas_w + x-2] == white;
            ffr = path_map.pixels[(y-1)*canvas_w + x-2] == white;
            break;
          }
/*          switch (gate) {
            case 0: // N
              set_xy(city.x, max(city.y - city.r_int, 2));
              break;
            case 1: // E
              set_xy(min(city.x + city.r_int, canvas_w-2), city.y);
              break;
            case 2: // S
              set_xy(city.x, min(city.y + city.r_int, canvas_h-2));
              break;
            case 3: // W
              set_xy(max(city.x - city.r_int, 2), city.y);
              break;
          } */
          
          if ((path_map.pixels[get_pixel_index()] == white) && f && fl && fr && ff && ffl && ffr) {
            if ((city.residents.size() == 1) && (random(1.0) < 0.3)) { // BIRTH
              if (DEBUG > 1) println("BIRTH (" + populace.size() + ")");
              Personoid p = new Personoid(x, y);
              p.destination = destination;
              p.update();
            }
            city.remove_resident(this);
            in_transit = true;
          } else {
            destination = null;
            in_transit = false;
            set_xy(city.x, city.y);
          }
        }
      }
    }

    if (in_transit) { // NAVIGATION
      if ((y+2) * canvas_w + x + 2 > canvas_w * canvas_h) print_info(); // DEBUG

      switch(momentum) {
        case 0: // N
          f   = path_map.pixels[(y-1)*canvas_w +   x] == white;
          fl  = path_map.pixels[(y-1)*canvas_w + x-1] == white;
          ffl = path_map.pixels[(y-2)*canvas_w + x-1] == white;
          fll = path_map.pixels[(y-1)*canvas_w + x-2] == white;
          fr  = path_map.pixels[(y-1)*canvas_w + x+1] == white;
          ffr = path_map.pixels[(y-2)*canvas_w + x+1] == white;
          frr = path_map.pixels[(y-1)*canvas_w + x+2] == white;
          l   = path_map.pixels[(y)*canvas_w   + x-1] == white;
          ll  = path_map.pixels[(y)*canvas_w   + x-2] == white;
          r   = path_map.pixels[(y)*canvas_w   + x+1] == white;
          rr  = path_map.pixels[(y)*canvas_w   + x+2] == white;
          bl  = path_map.pixels[(y+1)*canvas_w + x-1] == white;
          bll = path_map.pixels[(y+1)*canvas_w + x-2] == white;
          br  = path_map.pixels[(y+1)*canvas_w + x+1] == white;
          brr = path_map.pixels[(y+1)*canvas_w + x+2] == white;
          break;
        case 1: // E
          f   = path_map.pixels[(y)*canvas_w   + x+1] == white;
          fl  = path_map.pixels[(y-1)*canvas_w + x+1] == white;
          ffl = path_map.pixels[(y-1)*canvas_w + x+2] == white;
          fll = path_map.pixels[(y-2)*canvas_w + x+1] == white;
          fr  = path_map.pixels[(y+1)*canvas_w + x+1] == white;
          ffr = path_map.pixels[(y+1)*canvas_w + x+2] == white;
          frr = path_map.pixels[(y+2)*canvas_w + x+1] == white;
          l   = path_map.pixels[(y-1)*canvas_w +   x] == white;
          ll  = path_map.pixels[(y-2)*canvas_w +   x] == white;
          r   = path_map.pixels[(y+1)*canvas_w +   x] == white;
          rr  = path_map.pixels[(y+2)*canvas_w +   x] == white;
          bl  = path_map.pixels[(y-1)*canvas_w + x-1] == white;
          bll = path_map.pixels[(y-2)*canvas_w + x-1] == white;
          br  = path_map.pixels[(y+1)*canvas_w + x-1] == white;
          brr = path_map.pixels[(y+2)*canvas_w + x-1] == white;
          break;
        case 2: // S
          f   = path_map.pixels[(y+1)*canvas_w +   x] == white;
          fl  = path_map.pixels[(y+1)*canvas_w + x+1] == white;
          ffl = path_map.pixels[(y+2)*canvas_w + x+1] == white;
          fll = path_map.pixels[(y+1)*canvas_w + x+2] == white;
          fr  = path_map.pixels[(y+1)*canvas_w + x-1] == white;
          ffr = path_map.pixels[(y+2)*canvas_w + x-1] == white;
          frr = path_map.pixels[(y+1)*canvas_w + x-2] == white;
          l   = path_map.pixels[(y)*canvas_w   + x+1] == white;
          ll  = path_map.pixels[(y)*canvas_w   + x+2] == white;
          r   = path_map.pixels[(y)*canvas_w   + x-1] == white;
          rr  = path_map.pixels[(y)*canvas_w   + x-2] == white;
          bl  = path_map.pixels[(y-1)*canvas_w + x+1] == white;
          bll = path_map.pixels[(y-1)*canvas_w + x+2] == white;
          br  = path_map.pixels[(y-1)*canvas_w + x-1] == white;
          brr = path_map.pixels[(y-1)*canvas_w + x-2] == white;
          break;
        case 3: // W
          f   = path_map.pixels[(y)*canvas_w   + x-1] == white;
          fl  = path_map.pixels[(y+1)*canvas_w + x-1] == white;
          ffl = path_map.pixels[(y+1)*canvas_w + x-2] == white;
          fll = path_map.pixels[(y+2)*canvas_w + x-1] == white;
          fr  = path_map.pixels[(y-1)*canvas_w + x-1] == white;
          ffr = path_map.pixels[(y-1)*canvas_w + x-2] == white;
          frr = path_map.pixels[(y-2)*canvas_w + x-1] == white;
          l   = path_map.pixels[(y+1)*canvas_w   + x] == white;
          ll  = path_map.pixels[(y+2)*canvas_w   + x] == white;
          r   = path_map.pixels[(y-1)*canvas_w   + x] == white;
          rr  = path_map.pixels[(y-2)*canvas_w   + x] == white;
          bl  = path_map.pixels[(y+1)*canvas_w + x+1] == white;
          bll = path_map.pixels[(y+2)*canvas_w + x+1] == white;
          br  = path_map.pixels[(y-1)*canvas_w + x+1] == white;
          brr = path_map.pixels[(y-2)*canvas_w + x+1] == white;
          break;
      }
      
      switch(momentum) {
        case 0:
          if ((city == null) && (time_of_last_turn != last_step) && (destination.y + destination.r >= y)) { // overshooting; turn...
            if ((destination.x + destination.r-1 > x)
                && r && rr && br && fr && brr && frr && ffr) {
              momentum = (momentum+1)%4; // turn E
//              x++;
              set_xy(x+1, y);
              time_of_last_turn = now;
              break;
            } else if ((destination.x - destination.r+1 <= x)
                        && l && ll && bl && fl && bll && fll && ffl) {
              momentum--; if (momentum < 0) { momentum = 3; }
//              x--; // turn W
              set_xy(x-1, y);
              time_of_last_turn = now;
              break;
            }
          }

          ff  = path_map.pixels[(y-2)*canvas_w +   x] == white;

          if (f && ff && ((time_of_last_turn == last_step) || (fr && fl))) {
            set_xy(x, y-1); //y--; // continue N
          } else {
            if ((destination.x + destination.r-1 > x)
                && r && rr && br && fr && brr && frr) {
              momentum = (momentum+1)%4; // turn E
              set_xy(x+1, y);//x++;
              time_of_last_turn = now;
              break;
            } else if (l && ll && bl && fl && bll && fll) {
              momentum--; if (momentum < 0) { momentum = 3; } // turn W
              set_xy(x-1, y); //x--; 
              time_of_last_turn = now;
              break;
            } else if (r && rr && br && fr && brr && frr) {
              momentum = (momentum+1)%4; // turn E
              set_xy(x+1, y); //x++;
              time_of_last_turn = now;
              break;
            } else {
              if (random(1.0) < trapped_personoid_dies_odds) {
                if (DEBUG > 1) println("DEATH trapped (" + populace.size() + ")");
                die();
              } else {
                if (DEBUG > 1) println("NEW CITY trapped (" + cities.size() + ")");
                City c = new City(x, y);
                if (city != null) exit_city();
                enter_city(c);
                c.add_resident(this);
              }
            }
          }
          break;
          
        case 1: // E
          if ((city == null) && (time_of_last_turn != last_step) && (destination.x - destination.r <= x)) {
            if ((destination.y + destination.r-1 > y)
                && r && rr && br && fr && brr && frr && ffr) {
              momentum = (momentum+1)%4;
              set_xy(x, y+1); //y++;
              time_of_last_turn = now;
              break;
            } else if ((destination.y - destination.r+1 <= y)
                        && l && ll && bl && fl && bll && fll & ffl) { 
              momentum--; if (momentum < 0) { momentum = 3; }
              set_xy(x, y-1);//y--;
              time_of_last_turn = now;
              break;
            }
          }

          ff  = path_map.pixels[(y)*canvas_w   + x+2] == white;

          if (f && ff && ((time_of_last_turn == last_step) || (fr && fl))) {
            set_xy(x+1, y);//x++;
          } else {
            if ((destination.y + destination.r-1 > y)
                && r && rr && br && fr && brr && frr) {
              momentum = (momentum+1)%4;
              set_xy(x, y+1);//y++;
              time_of_last_turn = now;
              break;
            } else if (l && ll && bl && fl && bll && fll) {
              momentum--; if (momentum < 0) { momentum = 3; }
              set_xy(x, y-1);//y--;
              time_of_last_turn = now;
              break;
            } else if (r && rr && br && fr && brr && frr) {
              momentum = (momentum+1)%4;
              set_xy(x, y+1);//y++;
              time_of_last_turn = now;
              break;
            } else {
              if (random(1.0) < trapped_personoid_dies_odds) {
                if (DEBUG > 1) println("DEATH trapped (" + populace.size() + ")");
                die();
              } else {
                if (DEBUG > 1) println("NEW CITY trapped (" + cities.size() + ")");
                City c = new City(x, y);
                if (city != null) exit_city();
                enter_city(c);
                c.add_resident(this);
              }
            }
          }
          break;
          
          case 2: // S
          if ((city == null) && (time_of_last_turn != last_step) && (destination.y - destination.r <= y)) {
            if ((destination.x - destination.r+1 < x) 
                && r && rr && br && fr && brr && frr && ffr) {
              momentum = (momentum+1)%4;
              set_xy(x-1, y);//x--;
              time_of_last_turn = now;
              break;
            } else if ((destination.x + destination.r-1 >= x)
                        && l && ll && bl && fl && bll && fll && ffl) {
              momentum--; if (momentum < 0) { momentum = 3; }
              set_xy(x+1, y);//x++;
              time_of_last_turn = now;
              break;
            }
          }

          ff  = path_map.pixels[(y+2)*canvas_w +   x] == white;

          if (f && ff && ((time_of_last_turn == last_step) || (fr && fl))) {
            set_xy(x, y+1);//y++;
          } else {
            if ((destination.x - destination.r+1 < x)
                && r && rr && br && fr && brr && frr) {
              momentum = (momentum+1)%4;
              set_xy(x-1, y);//x--;
              time_of_last_turn = now;
              break;
            } else if (l && ll && bl && fl && bll && fll) {
              momentum--; if (momentum < 0) { momentum = 3; }
              set_xy(x+1, y);//x++;
              time_of_last_turn = now;
              break;
            } else if (r && rr && br && fr && brr && frr) {
              momentum = (momentum+1)%4;
              set_xy(x-1, y);//x--;
              time_of_last_turn = now;
              break;
            } else {
              if (random(1.0) < trapped_personoid_dies_odds) {
                if (DEBUG > 1) println("DEATH trapped (" + populace.size() + ")");
                die();
              } else {
                if (DEBUG > 1) println("NEW CITY trapped (" + cities.size() + ")"); // debug
                City c = new City(x, y);
                if (city != null) exit_city();
                enter_city(c);
                c.add_resident(this);
              }
            }
          }
          break;
          
          case 3: // W
          if ((city == null) && (time_of_last_turn != last_step) && (destination.x + destination.r >= x)) {
            if ((destination.y - destination.r+1 < y)
                && r && rr && br && fr && brr && frr && ffr) {
              momentum = (momentum+1)%4;
              set_xy(x, y-1);//y--;
              time_of_last_turn = now;
              break;
            } else if ((destination.y + destination.r-1 >= y)
                        && l && ll && bl && fl && bll && fll && ffl) { 
              momentum--; if (momentum < 0) { momentum = 3; }
              set_xy(x, y+1);//y++;
              time_of_last_turn = now;
              break;
            }
          }
          
          ff  = path_map.pixels[(y)*canvas_w   + x-2] == white;

          if (f && ff && ((time_of_last_turn == last_step) || (fr && fl))) {
            set_xy(x-1, y);//x--;
          } else {
            if ((destination.y - destination.r+1 < y)
                && r && rr && br && fr && brr && frr) {
              momentum = (momentum+1)%4;
              set_xy(x, y-1);//y--;
              time_of_last_turn = now;
              break;
            } else if (l && ll && bl && fl && bll && fll) {
              momentum--; if (momentum < 0) { momentum = 3; }
              set_xy(x, y+1);//y++;
              time_of_last_turn = now;
              break;
            } else if (r && rr && br && fr && brr && frr) {
              momentum = (momentum+1)%4;
              set_xy(x, y-1);//y--;
              time_of_last_turn = now;
              break;
            } else {
              if (random(1.0) < trapped_personoid_dies_odds) {
                if (DEBUG > 1) println("DEATH trapped (" + populace.size() + ")");
                die();
              } else {
                if (DEBUG > 1) println("NEW CITY trapped (" + cities.size() + ")");
                City c = new City(x, y);
                if (city != null) exit_city();
                enter_city(c);
                c.add_resident(this);
              }
            }
          }
          break;
      
      }
          
      if (time_in_transit > 1) {
        for (City c : cities) { // CAPTURE
          if (sqrt(pow(abs(c.x - x), 2) + pow(abs(c.y - y), 2)) < c.r + 0.9) {
            enter_city(c);
            c.add_resident(this);
            break;
          }
        }
      }
      
      if (in_transit) {
        path_map.pixels[get_pixel_index()] = (time_in_transit>225) ? black : color(225 - time_in_transit);
        active_pixels.putIfAbsent(get_pixel_index(), true);
        time_in_transit++;
      }
    }
  }
  
  void display() {
  }
}
