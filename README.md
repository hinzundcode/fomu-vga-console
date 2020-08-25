# fomu vga console

![demo](https://raw.githubusercontent.com/hinzundcode/fomu-vga-console/master/demo.jpg)

## pinout

* user_1 to R/G/B (VGA pins 1, 2 and 3)
* user_2 to Ground
* user_3 to HSYNC (VGA pin 13) 
* user_4 to VSYNC (VGA pin 15)

## build & run

```
$ python vga.py --board pvt
$ dfu-util -D build/gateware/fomu_pvt.dfu
$ python write.py Hello from fomu
```

### more examples

```
$ python write.py -x 10 -y 10 Hello
```

```
$ python write.py --clear
```

```
$ uptime | python write.py 
```

```
$ while true; do python write.py <<<$(date); sleep 0.5; done;
```

## font

This project uses the [Unicode VGA font](http://www.inp.nsk.su./~bolkhov/files/fonts/univga/) which stands under the X license.
