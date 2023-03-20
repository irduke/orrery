import csv


moon_positions = []
earth_positions = []

with open('database.csv') as file:
    linereader = csv.reader(file, delimiter=',')
    for line in linereader:
        new_line = []
        _, year, day, time, moon_pos, earth_pos = line
        
        #Skip over column header and any years outside range
        try:
            year = int(year, 2)
        except ValueError:
            continue
        if year < 1523:
            continue
        elif year > 2523:
            break
        else:
            #Convert motor positions to int then store in list variable
            moon_val = int(moon_pos, 2)
            earth_val = int(earth_pos, 2)

            moon_positions.append(str(moon_val))
            earth_positions.append(str(earth_val))


with open('earthdata.txt', 'w') as earthdb:
    for i, val in enumerate(earth_positions):
        if i % 500000 == 0 and i != 0:
            earthdb.write("\n"*50)
            earthdb.write(f'{val},')
        if i % 50 == 0 and i != 0:
            earthdb.write("{\n}" + val + ",")
        elif i != len(earth_positions) -1:
            earthdb.write(f'{val},')
        else:
            earthdb.write(val)

with open('moondata.txt', 'w') as moondb:
    for i, val in enumerate(moon_positions):
        if i % 500000 == 0 and i != 0:
            moondb.write("\n"*50)
            moondb.write(f'{val},')
        elif i % 50 == 0 and i != 0:
            moondb.write("{\n}" + val + ",")
        elif i != len(moon_positions) -1:
            moondb.write(f'{val},')
        else:
            moondb.write(val)
