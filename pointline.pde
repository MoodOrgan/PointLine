/////////////////////////////////////////////////////////// .- /////////////////////////////////////////////////////////
// 
// timm.mason@gmail.com
// 201805XX – 20190510

// TODO
// rewrite NAV
//   when going toward large city, the corner area upsets navigation
//   DEPART - check neighbors around gate
// add REC mode
// rewrite City.display() with gradient
// use angles instead of rectilinear paths?

boolean DEBUG = false;
boolean HIRES = false;
boolean REC   = false;

int canvas_w = 800; //1400;
int canvas_h = 600; //800;

PImage path_map;

int pixel_index;

color red   = color(255, 0, 0);
color white = color(255, 255, 255);
color almost_white = color(254, 254, 254);
color black = color(0, 0, 0);
color color_inc = color(1, 1, 1);
color grey = color(128, 128, 128);

int step_counter = 0;
int fade_turn_period = 5;

int time_step = 1; // milliseconds
int now;
int last_step;

int init_cities  = 24;
int made_cities = 0; // for initialization procedure
ArrayList<City> cities;

int init_population = 256; //512;
ArrayList<Personoid> populace;

void settings() {
    size(canvas_w, canvas_h);
}

void setup() {
  path_map = createImage(canvas_w, canvas_h, RGB);
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
  for (int i=0; i<init_cities; i++) { // random arrangement
    cities.add(new City());
    made_cities++;
  } 
  
  populace = new ArrayList<Personoid>(init_population);
  for (int i=0; i<init_population; i++) {
    new Personoid();
  }
  
  now = millis();
  last_step = now;
}

void draw() {
  now = millis();
  path_map.loadPixels();

  if (now - time_step > last_step) {
    step_counter++;

    for (int i=0; i<cities.size(); i++) {
      cities.get(i).update();
    }
    for (int i=0; i<populace.size(); i++) {
      populace.get(i).update();
    }
    
    if (step_counter % fade_turn_period == 0) {    // FADE TURN
      if (cities.size() >= 3) {
        City a, b;
        
        a = cities.get(int(random(cities.size())));
        do {
          b = cities.get(int(random(cities.size())));
        } while (a == b);
        
        if ((random(1.0) < 0.09) && (a.residents.size() <= 1) && (b.residents.size() <= 1) 
            && (now - a.creation_time > 1024) && (now - b.creation_time > 1024)) { // SEEK
          if (DEBUG) println("SEEK: a = " + a + ",\tb = " + b);
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
  
            if (DEBUG) println("\ta: new Personoid(" + populace.size() + ")");
          }
              
          if (b.residents.size() > 0) {
            for (int i=b.residents.size()-1; i>=0; i--) {
              p = b.residents.get(i);
              b.remove_resident(p);
              p.destination = new_destination;
            }
          } else {
            p = new Personoid(b.x, b.y);
            p.destination = new_destination;
            p.update();
            
            if (DEBUG) println("\tb: new Personoid(" + populace.size() + ")");
          }
        }
      }

      for (int x=1; x<canvas_w*canvas_h-1; x++) // FADE PATHS
        if (path_map.pixels[x] != white)
          path_map.pixels[x] = color(min((path_map.pixels[x] >> 16 & 0xFF) + 1.0, 255.0)); 
          
      if (path_map.pixels[1] == almost_white) { // fix black border
        for (int i=0; i<canvas_h; i++) {
          path_map.pixels[i*canvas_w + 0] = black;
          path_map.pixels[i*canvas_w + canvas_w-1] = black;
        }
        for (int j=0; j<canvas_w; j++) {
          path_map.pixels[j] = black;
          path_map.pixels[(canvas_h-1)*canvas_w + j] = black;
        }
      }
    }

    path_map.updatePixels();
    image(path_map, 0, 0);
    
    for (City c : cities) {
      c.display();
    }
    
    if (HIRES) { filter(BLUR); }

    last_step = now;
  }
}

class City {
  int x, y;
  float r, target_r;
  int r_int;
  int creation_time;
  int last_departure;
  int last_city_checked;
  ArrayList<Personoid> residents;
  
  City() {
    boolean coordinates_taken;
    
    residents = new ArrayList<Personoid>();

    if (DEBUG) print("city " + made_cities + "\t"); // debug
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
      println();
    } while(coordinates_taken);
    
    r = 1.0;
    calculate_r();
    r_int = int(r);
    creation_time = now;
    last_departure = 0;
    last_city_checked = 0;
  }
  
  City(int x_in, int y_in) {
    residents = new ArrayList<Personoid>();
    x = x_in;
    y = y_in;
    r = 1.0;
    calculate_r();
    r_int = int(r);
    creation_time = now;
    last_departure = 0;
    last_city_checked = 0;
  }
  
  void update() {
    City c;

    calculate_r();
    if (r <= 0.01) die();
    
    if (r_int > 75) {
      Personoid p;
      boolean xy_found = false;
      int trial_x=0, trial_y=0;
      if (DEBUG) { println("EXPLODE"); }
      for (int j=residents.size()-1; j>=0; j--) {
        for (int i=0; i<2; i++) {
          xy_found = false;
          trial_x = x + int(random(2*r_int))-r_int;
          trial_y = y + int(random(2*r_int))-r_int;
          if ((path_map.pixels[trial_y*canvas_w + trial_x] == white)
              && (sqrt(pow(abs(trial_x - x), 2) + pow(abs(trial_y - y), 2)) <= r)) {
              xy_found = true;
              break;
          }
        }
        p = residents.get(j);
        remove_resident(p);

        if (xy_found) {
          p.x = trial_x;
          p.y = trial_y;
          do {
            p.destination = cities.get(int(random(cities.size())));
          } while (p.destination == this);
        } else {
          p.die();
        }
      }
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
          if (DEBUG) println("EXCHANGE " + this + " \tsize = " + c.residents.size());
          for (int i=residents.size()-1; i>=0; i--) {
            if (random(1.0) > 0.5) { // if we surround city c, they randomly take half our residents
              p = residents.get(i);
              this.remove_resident(p);
              c.add_resident(p);
            }
          } 
        } else {      // ABSORB
          if (DEBUG) println("ABSORB " + c + " \tsize = " + c.residents.size());
          for (int i=c.residents.size()-1; i>=0; i--) {
            Personoid p = c.residents.get(i);
            c.remove_resident(p);
            this.add_resident(p);
          }
          c.die();
        }
      }
    }
  }
  
  void display() {
    noStroke();

    if (r <= 1.0) {
      fill(color(red));
    } else {
      fill(color(min(64.0-6.0*r + (now - last_departure)/96.0, 200), 128)); 
    }
    ellipse(x, y, 4.0*r, 4.0*r);
    fill(color(255, 212));
    ellipse(x, y, 2.0*r, 2.0*r);
  }
  
  void calculate_r() {
    target_r = float(residents.size());
    r += (target_r - r) / 100.0;
    r_int = int(r);
  }
  
  void add_resident(Personoid p) {
    residents.add(p);
    p.city = this;
    p.in_transit = false;
    p.time_in_city = 0;
    p.time_in_transit = 0;
    p.x = x; p.y = y;
  }
  
  void remove_resident(Personoid p) {
    residents.remove(p);
    last_departure = now;
    cities.remove(this); cities.add(this);     // move self to head of cities[]
    p.exit_city();
  }
  
  void die() {
    // population already cleared ?
    if (DEBUG) println("DEAD CITY (" + cities.size() + ")");
    cities.remove(this);
  }
}

class Personoid {
  int x, y;
  int momentum; // NESW
  boolean in_transit = false;
  City city;
  City destination;
  int time_in_city = 0;
  int time_in_transit = 0;
  int time_of_last_turn = 0;
  
  Personoid(City c) { // Personoid in City c
    city = c;
    destination = null;
    x = city.x;
    y = city.y;
    momentum = int(random(4));
    populace.add(this);
  }
  
  Personoid() { // Personoid in random City
    city = cities.get(int(random(cities.size())));
    city.add_resident(this);
    destination = null;
    x = city.x;
    y = city.y;
    momentum = int(random(4));
    populace.add(this);
  }
  
  Personoid(int new_x, int new_y) { // Personoid not in city
    city = null;
    x = new_x;
    y = new_y;
    momentum = int(random(4));
    in_transit = true;
    populace.add(this);
  }
  
  void die() {
    if (city != null) city.remove_resident(this);
    populace.remove(this);
  }
  
  void exit_city() {
    city = null;
    in_transit = true;
    time_in_city = 0;
    time_in_transit = 0;
  }
  
  void update() {
    if (!in_transit) { // Personoid occupies a city
      time_in_city++;
      if ((time_in_city > 128) && (city.last_departure < (last_step - time_step*1024))) {
        int min = populace.size();
        for (City c : cities) {
          if ((abs(c.x - city.x) > canvas_w/3) || (abs(c.y - city.y) > canvas_h/3)) continue;
          if (c.residents.size() < min) {
            min = c.residents.size();
            destination = c;
            if (min <= 1) break;
            if (random(1.0) > 0.95) break;
          }
        }
        if (random(12000) < (city.residents.size() - min + 1)) { // DEPART
          City c = city;
          int gate;
          do {
            gate = int(random(4));
          } while (((gate == 0) && (destination.y > y)) ||
                   ((gate == 1) && (destination.x < x)) ||
                   ((gate == 2) && (destination.y < y)) ||
                   ((gate == 3) && (destination.x > x)));
          do {
            momentum = int(random(4));
          } while ((gate + 2) % 4 == momentum);

          switch (gate) {
            case 0: // N
              x = city.x;
              y = city.y - int(city.target_r);
              break;
            case 1: // E
              x = city.x + int(city.target_r);
              y = city.y;
              break;
            case 2: // S
              x = city.x;
              y = city.y + int(city.target_r);
              break;
            case 3: // W
              x = city.x - int(city.target_r);
              y = city.y;
              break;
          }

          if (path_map.pixels[y*canvas_w + x] == white) {
            int city_radius = int(city.target_r);

            if ((city.residents.size() == 1) && (random(1.0) < 0.3)) { // BIRTH
              if (DEBUG) println("BIRTH (" + populace.size() + ")");
              Personoid p = new Personoid(x, y);
              p.destination = destination;
              p.update();
            }
            city.remove_resident(this);
          } else {
            destination = null;
            in_transit = false;
            x = city.x; y = city.y;
          }
        }
      }
    }

    if (in_transit) { // NAVIGATION
      int f, ff, fl, fll, fr, frr, ffl, ffr, l, ll, r, rr, bl, bll, br, brr;

      switch(momentum) {
        case 0: // N
          f   = path_map.pixels[(y-1)*canvas_w + x];
          fl  = path_map.pixels[(y-1)*canvas_w + x-1];
          ffl = path_map.pixels[(y-2)*canvas_w + x-1];
          fll = path_map.pixels[(y-1)*canvas_w + x-2];
          fr  = path_map.pixels[(y-1)*canvas_w + x+1];
          ffr = path_map.pixels[(y-2)*canvas_w + x+1];
          frr = path_map.pixels[(y-1)*canvas_w + x+2];
          l   = path_map.pixels[(y)*canvas_w   + x-1];
          ll  = path_map.pixels[(y)*canvas_w   + x-2];
          r   = path_map.pixels[(y)*canvas_w   + x+1];
          rr  = path_map.pixels[(y)*canvas_w   + x+2];
          bl  = path_map.pixels[(y+1)*canvas_w + x-1];
          bll = path_map.pixels[(y+1)*canvas_w + x-2];
          br  = path_map.pixels[(y+1)*canvas_w + x+1];
          brr = path_map.pixels[(y+1)*canvas_w + x+2];
          
          if ((city == null) && (time_of_last_turn != last_step) && (destination.y + destination.r >= y)) { // overshooting; turn...
            if ((destination.x + destination.r-1 > x)
                && (r == white) && (rr == white) && (br == white) && (fr == white) && (brr == white) && (frr == white) && (ffr == white)) {
              momentum = (momentum+1)%4; // turn E
              x++;
              time_of_last_turn = now;
              break;
            } else if ((destination.x - destination.r+1 <= x)
                        && (l == white) && (ll == white) && (bl == white) && (fl == white) && (bll == white) && (fll == white) && (ffl == white)) {
              momentum--; if (momentum < 0) { momentum = 3; }
              x--; // turn W
              time_of_last_turn = now;
              break;
            }
          }

          ff  = path_map.pixels[(y-2)*canvas_w + x];

          if ((f == white) && (ff == white) && ((time_of_last_turn == last_step) || ((fr == white) && (fl == white)))) {
            y--; // continue N
          } else {
            if ((destination.x + destination.r-1 > x)
                && (r == white) && (rr == white) && (br == white) && (fr == white) && (brr == white) && (frr == white)) {
              momentum = (momentum+1)%4; // turn E
              x++;
              time_of_last_turn = now;
              break;
            } else if ((l == white) && (ll == white) && (bl == white) && (fl == white) && (bll == white) && (fll == white)) {
              momentum--; if (momentum < 0) { momentum = 3; } // turn W
              x--; 
              time_of_last_turn = now;
              break;
            } else if ((r == white) && (rr == white) && (br == white) && (fr == white) && (brr == white) && (frr == white)) {
              momentum = (momentum+1)%4; // turn E
              x++;
              time_of_last_turn = now;
              break;
            } else {
              if (random(1.0) < 0.1) {
                if (DEBUG) println("DEATH (" + populace.size() + ")");
                die();
              } else {
                if (DEBUG) println("NEW CITY (" + cities.size() + ")");
                City c = new City(x, y);
                cities.add(c);
                if (city != null) city.remove_resident(this);
                c.add_resident(this);
              }
            }
          }
          break;
          
        case 1: // E
          f   = path_map.pixels[(y)*canvas_w   + x+1];
          fl  = path_map.pixels[(y-1)*canvas_w + x+1];
          ffl = path_map.pixels[(y-1)*canvas_w + x+2];
          fll = path_map.pixels[(y-2)*canvas_w + x+1];
          fr  = path_map.pixels[(y+1)*canvas_w + x+1];
          ffr = path_map.pixels[(y+1)*canvas_w + x+2];
          frr = path_map.pixels[(y+2)*canvas_w + x+1];
          l   = path_map.pixels[(y-1)*canvas_w   + x];
          ll  = path_map.pixels[(y-2)*canvas_w   + x];
          r   = path_map.pixels[(y+1)*canvas_w   + x];
          rr  = path_map.pixels[(y+2)*canvas_w   + x];
          bl  = path_map.pixels[(y-1)*canvas_w + x-1];
          bll = path_map.pixels[(y-2)*canvas_w + x-1];
          br  = path_map.pixels[(y+1)*canvas_w + x-1];
          brr = path_map.pixels[(y+2)*canvas_w + x-1];
          
          if ((city == null) && (time_of_last_turn != last_step) && (destination.x - destination.r <= x)) {
            if ((destination.y + destination.r-1 > y)
                && (r == white) && (rr == white) && (br == white) && (fr == white) && (brr == white) && (frr == white) && (ffr == white)) {
              momentum = (momentum+1)%4;
              y++;
              time_of_last_turn = now;
              break;
            } else if ((destination.y - destination.r+1 <= y)
                        && (l == white) && (ll == white) && (bl == white) && (fl == white) && (bll == white) && (fll == white) & (ffl == white)) { 
              momentum--; if (momentum < 0) { momentum = 3; }
              y--;
              time_of_last_turn = now;
              break;
            }
          }

          ff  = path_map.pixels[(y)*canvas_w   + x+2];

          if ((f == white) && (ff == white) && ((time_of_last_turn == last_step) || ((fr == white) && (fl == white)))) {
            x++;
          } else {
            if ((destination.y + destination.r-1 > y)
                && (r == white) && (rr == white) && (br == white) && (fr == white) && (brr == white) && (frr == white)) {
              momentum = (momentum+1)%4;
              y++;
              time_of_last_turn = now;
              break;
            } else if ((l == white) && (ll == white) && (bl == white) && (fl == white) && (bll == white) && (fll == white)) {
              momentum--; if (momentum < 0) { momentum = 3; }
              y--;
              time_of_last_turn = now;
              break;
            } else if ((r == white) && (rr == white) && (br == white) && (fr == white) && (brr == white) && (frr == white)) {
              momentum = (momentum+1)%4;
              y++;
              time_of_last_turn = now;
              break;
            } else {
              if (random(1.0) < 0.1) {
                if (DEBUG) println("DEATH (" + populace.size() + ")");
                die();
              } else {
                if (DEBUG) println("NEW CITY (" + cities.size() + ")");
                City c = new City(x, y);
                cities.add(c);
                if (city != null) city.remove_resident(this);
                c.add_resident(this);
              }
            }
          }
          break;
          
          case 2: // S
          f   = path_map.pixels[(y+1)*canvas_w + x];
          fl  = path_map.pixels[(y+1)*canvas_w + x+1];
          ffl = path_map.pixels[(y+2)*canvas_w + x+1];
          fll = path_map.pixels[(y+1)*canvas_w + x+2];
          fr  = path_map.pixels[(y+1)*canvas_w + x-1];
          ffr = path_map.pixels[(y+2)*canvas_w + x-1];
          frr = path_map.pixels[(y+1)*canvas_w + x-2];
          l   = path_map.pixels[(y)*canvas_w   + x+1];
          ll  = path_map.pixels[(y)*canvas_w   + x+2];
          r   = path_map.pixels[(y)*canvas_w   + x-1];
          rr  = path_map.pixels[(y)*canvas_w   + x-2];
          bl  = path_map.pixels[(y-1)*canvas_w + x+1];
          bll = path_map.pixels[(y-1)*canvas_w + x+2];
          br  = path_map.pixels[(y-1)*canvas_w + x-1];
          brr = path_map.pixels[(y-1)*canvas_w + x-2];
          
          if ((city == null) && (time_of_last_turn != last_step) && (destination.y - destination.r <= y)) {
            if ((destination.x - destination.r+1 < x) 
                && (r == white) && (rr == white) && (br == white) && (fr == white) && (brr == white) && (frr == white) && (ffr == white)) {
              momentum = (momentum+1)%4;
              x--;
              time_of_last_turn = now;
              break;
            } else if ((destination.x + destination.r-1 >= x)
                        && (l == white) && (ll == white) && (bl == white) && (fl == white) && (bll == white) && (fll == white) && (ffl == white)) {
              momentum--; if (momentum < 0) { momentum = 3; }
              x++;
              time_of_last_turn = now;
              break;
            }
          }

          ff  = path_map.pixels[(y+2)*canvas_w + x];

          if ((f == white) && (ff == white) && ((time_of_last_turn == last_step) || ((fr == white) && (fl == white)))) {
            y++;
          } else {
            if ((destination.x - destination.r+1 < x)
                && (r == white) && (rr == white) && (br == white) && (fr == white) && (brr == white) && (frr == white)) {
              momentum = (momentum+1)%4;
              x--;
              time_of_last_turn = now;
              break;
            } else if ((l == white) && (ll == white) && (bl == white) && (fl == white) && (bll == white) && (fll == white)) {
              momentum--; if (momentum < 0) { momentum = 3; }
              x++;
              time_of_last_turn = now;
              break;
            } else if ((r == white) && (rr == white) && (br == white) && (fr == white) && (brr == white) && (frr == white)) {
              momentum = (momentum+1)%4;
              x--;
              time_of_last_turn = now;
              break;
            } else {
              if (random(1.0) < 0.1) {
                if (DEBUG) println("DEATH (" + populace.size() + ")");
                die();
              } else {
                if (DEBUG) println("NEW CITY (" + cities.size() + ")"); // debug
                City c = new City(x, y);
                cities.add(c);
                if (city != null) city.remove_resident(this);
                c.add_resident(this);
              }
            }
          }
          break;
          
          case 3: // W
          f   = path_map.pixels[(y)*canvas_w   + x-1];
          fl  = path_map.pixels[(y+1)*canvas_w + x-1];
          ffl = path_map.pixels[(y+1)*canvas_w + x-2];
          fll = path_map.pixels[(y+2)*canvas_w + x-1];
          fr  = path_map.pixels[(y-1)*canvas_w + x-1];
          ffr = path_map.pixels[(y-1)*canvas_w + x-2];
          frr = path_map.pixels[(y-2)*canvas_w + x-1];
          l   = path_map.pixels[(y+1)*canvas_w   + x];
          ll  = path_map.pixels[(y+2)*canvas_w   + x];
          r   = path_map.pixels[(y-1)*canvas_w   + x];
          rr  = path_map.pixels[(y-2)*canvas_w   + x];
          bl  = path_map.pixels[(y+1)*canvas_w + x+1];
          bll = path_map.pixels[(y+2)*canvas_w + x+1];
          br  = path_map.pixels[(y-1)*canvas_w + x+1];
          brr = path_map.pixels[(y-2)*canvas_w + x+1];
          
          if ((city == null) && (time_of_last_turn != last_step) && (destination.x + destination.r >= x)) {
            if ((destination.y - destination.r+1 < y)
                && (r == white) && (rr == white) && (br == white) && (fr == white) && (brr == white) && (frr == white) && (ffr == white)) {
              momentum = (momentum+1)%4;
              y--;
              time_of_last_turn = now;
              break;
            } else if ((destination.y + destination.r-1 >= y)
                        && (l == white) && (ll == white) && (bl == white) && (fl == white) && (bll == white) && (fll == white) && (ffl == white)) { 
              momentum--; if (momentum < 0) { momentum = 3; }
              y++;
              time_of_last_turn = now;
              break;
            }
          }

          ff  = path_map.pixels[(y)*canvas_w   + x-2];
          
          if ((f == white) && (ff == white) && ((time_of_last_turn == last_step) || ((fr == white) && (fl == white)))) {
            x--;
          } else {
            if ((destination.y - destination.r+1 < y)
                && (r == white) && (rr == white) && (br == white) && (fr == white) && (brr == white) && (frr == white)) {
              momentum = (momentum+1)%4;
              y--;
              time_of_last_turn = now;
              break;
            } else if ((l == white) && (ll == white) && (bl == white) && (fl == white) && (bll == white) && (fll == white)) {
              momentum--; if (momentum < 0) { momentum = 3; }
              y++;
              time_of_last_turn = now;
              break;
            } else if ((r == white) && (rr == white) && (br == white) && (fr == white) && (brr == white) && (frr == white)) {
              momentum = (momentum+1)%4;
              y--;
              time_of_last_turn = now;
              break;
            } else {
              if (random(1.0) < 0.1) {
                if (DEBUG) println("DEATH (" + populace.size() + ")");
                die();
              } else {
                if (DEBUG) println("NEW CITY (" + cities.size() + ")");
                City c = new City(x, y);
                cities.add(c);
                if (city != null) city.remove_resident(this);
                c.add_resident(this);
              }
            }
          }
          break;
      
      }
          
      for (City c : cities) { // CAPTURE
        if ((time_in_transit > 4) && (sqrt(pow(abs(c.x - x), 2) + pow(abs(c.y - y), 2)) < c.r_int + 1)) {
          line(c.x, c.y, x, y);
          city = c;
          in_transit = false;
          time_in_city = 0;
          time_in_transit = 0;
          c.add_resident(this);
          x = c.x; y = c.y;
          break;
        } else {
          path_map.pixels[y*canvas_w + x] = (time_in_transit>225) ? black : color(225 - time_in_transit);
        }
      }
      
      time_in_transit++;
    }
  }
  
  void display() {
  }
}
