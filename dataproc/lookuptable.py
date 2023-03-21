with open("daylookuptable", "w") as file:
    for i in range(366):
        #motor_pos = min(int(i//0.005569458), 65535)
        motor_pos = min(int(i*126.301369863), 65535)
        #print(f'Day: {i}, Motor Position: {motor_pos}')
        byte = motor_pos.to_bytes(2, 'big')
        file.write(str(motor_pos))
        file.write(",")