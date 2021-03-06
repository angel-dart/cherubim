/// This is the simplest possible example of using Cherubim with multiple isolates.
///
/// Here, we just increment a `counter` number every time our server is visited.
/// Even though we are running multiple instances of our application, they can "share" one state.
library example.counter;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:angel_common/angel_common.dart';
import 'package:cherubim/cherubim.dart' as cherubim;
import 'package:cherubim/isolate_client.dart' as cherubim;
import 'package:cherubim/isolate_server.dart' as cherubim;

main() async {
  int nInstances = Platform.numberOfProcessors - 1;
  var isolateAdapter = new cherubim.IsolateAdapter();
  var server = new cherubim.Server(adapters: [isolateAdapter]);
  int alive = 3;

  var onDie = new ReceivePort()
    ..listen((_) {
      print('An instance died. RIP...');

      if (--alive == 0) {
        print('All instances have crashed! Shutting down...');
        Isolate.current.kill();
      }
    });

  print('Spawning $nInstances instance(s)');
  for (int i = 0; i < nInstances; i++) {
    Isolate.spawn(isolateMain, [i, isolateAdapter.receivePort.sendPort],
        onExit: onDie.sendPort);
  }

  server.start();
  print('Cherubim is now listening.');
}

void isolateMain(List args) {
  int id = args[0];
  SendPort server = args[1];

  var client = new cherubim.IsolateClient(server);
  client.connect(timeout: new Duration(seconds: 10)).then((_) async {
    var app = new Angel.custom(startShared);

    app.get('/', () async {
      try {
        var hits =
            await client.increment('hits', timeout: new Duration(seconds: 10));

        // Kill this instance after 10 seconds.
        //
        // This is just for the sake of this example, to force the server to eventually
        // run all instances.
        new Timer(new Duration(seconds: 10), () {
          Isolate.current.kill();
        });

        // Print a message just to prove that it's working in every instance.
        print('Instance #$id incremented hits to $hits');
        return {'hits': hits};
      } catch (e) {
        throw new AngelHttpException(e, message: e.toString());
      }
    });

    app.after.add(() => throw new AngelHttpException.notFound());
    app.responseFinalizers.add(gzip());
    await app.configure(logRequests());

    var server = await app.startServer(InternetAddress.LOOPBACK_IP_V4, 3000);
    print(
        'Instance #$id listening at http://${server.address.address}:${server.port}');
  }).catchError((e) {
    stderr.writeln('Instance #$id failed to start: $e');
    Isolate.current.kill();
  });
}
